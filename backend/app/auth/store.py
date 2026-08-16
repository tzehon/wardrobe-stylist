"""Durable SQLite state for anonymous App Attest installations.

Only authentication metadata is stored: challenges, public keys, opaque Apple receipts,
monotonic assertion counters, short-lived session hashes, and coarse rate
windows. Receipt snippets and wardrobe/catalog payloads never enter this store.
"""

from __future__ import annotations

import os
import sqlite3
import stat
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path


class StoreConflictError(RuntimeError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class RateLimitExceeded(RuntimeError):
    def __init__(self, retry_after: int) -> None:
        super().__init__("rate_limit_exceeded")
        self.retry_after = max(1, retry_after)


@dataclass(frozen=True)
class ChallengeRecord:
    challenge_id: str
    secret: bytes
    purpose: str
    key_id: str | None
    expires_at: int
    state: str
    payload_hash: bytes | None
    completed_session_id: str | None


@dataclass(frozen=True)
class ChallengeClaim:
    challenge: ChallengeRecord


@dataclass(frozen=True)
class InstallationRecord:
    installation_id: str
    key_id: str
    public_key_der: bytes
    opaque_receipt: bytes
    app_id: str
    attest_environment: str
    sign_count: int
    validation_category: int | None
    bundle_version: str | None
    revoked_at: int | None


@dataclass(frozen=True)
class SessionRecord:
    session_id: str
    installation_id: str
    expires_at: int


_SCHEMA = """
CREATE TABLE IF NOT EXISTS challenges (
    challenge_id TEXT PRIMARY KEY,
    secret BLOB NOT NULL,
    purpose TEXT NOT NULL CHECK (purpose IN ('attestation', 'assertion')),
    key_id TEXT,
    expires_at INTEGER NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('issued', 'processing', 'completed', 'failed')),
    payload_hash BLOB,
    completed_session_id TEXT,
    client_ip_hash TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS installations (
    installation_id TEXT PRIMARY KEY,
    key_id TEXT NOT NULL UNIQUE,
    public_key_der BLOB NOT NULL,
    receipt BLOB NOT NULL,
    app_id TEXT NOT NULL,
    attest_environment TEXT NOT NULL,
    sign_count INTEGER NOT NULL DEFAULT 0,
    validation_category INTEGER,
    bundle_version TEXT,
    attested_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL,
    revoked_at INTEGER
);

CREATE TABLE IF NOT EXISTS sessions (
    session_id TEXT PRIMARY KEY,
    installation_id TEXT NOT NULL REFERENCES installations(installation_id) ON DELETE CASCADE,
    token_hash BLOB NOT NULL UNIQUE,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    revoked_at INTEGER
);

CREATE INDEX IF NOT EXISTS sessions_token_hash_idx ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS sessions_expiry_idx ON sessions(expires_at);

CREATE TABLE IF NOT EXISTS rate_windows (
    scope TEXT NOT NULL,
    subject_hash TEXT NOT NULL,
    window_start INTEGER NOT NULL,
    request_count INTEGER NOT NULL,
    PRIMARY KEY (scope, subject_hash, window_start)
);
"""

_INSTALLATIONS_V2_SCHEMA = """
CREATE TABLE installations_v2 (
    installation_id TEXT PRIMARY KEY,
    key_id TEXT NOT NULL UNIQUE,
    public_key_der BLOB NOT NULL,
    receipt BLOB NOT NULL,
    app_id TEXT NOT NULL,
    attest_environment TEXT NOT NULL,
    sign_count INTEGER NOT NULL DEFAULT 0,
    validation_category INTEGER,
    bundle_version TEXT,
    attested_at INTEGER NOT NULL,
    last_seen_at INTEGER NOT NULL,
    revoked_at INTEGER
)
"""


class AuthStore:
    def __init__(self, path: Path) -> None:
        self.path = path

    @contextmanager
    def _connection(self) -> Iterator[sqlite3.Connection]:
        self._ensure_private_directory()
        connection = sqlite3.connect(self.path, timeout=5.0)
        connection.row_factory = sqlite3.Row
        try:
            connection.execute("PRAGMA foreign_keys = ON")
            connection.execute("PRAGMA busy_timeout = 5000")
            connection.execute("PRAGMA synchronous = FULL")
            yield connection
        finally:
            connection.close()

    def _ensure_private_directory(self) -> None:
        parent = self.path.parent
        try:
            parent.mkdir(mode=0o700, parents=True, exist_ok=False)
        except FileExistsError:
            pass
        if parent.is_symlink():
            raise PermissionError("App Attest database directory must not be a symlink.")
        metadata = parent.stat()
        if not stat.S_ISDIR(metadata.st_mode):
            raise PermissionError("App Attest database parent must be a directory.")
        if metadata.st_uid != os.geteuid():
            raise PermissionError("App Attest database directory must be owned by this process.")
        if stat.S_IMODE(metadata.st_mode) != 0o700:
            raise PermissionError("App Attest database directory permissions must be 0700.")

    def initialize(self) -> None:
        with self._connection() as connection:
            connection.execute("PRAGMA journal_mode = WAL")
            connection.executescript(_SCHEMA)
            columns = {
                str(row["name"]): int(row["notnull"])
                for row in connection.execute("PRAGMA table_info(installations)")
            }
            if columns.get("validation_category") == 1 or columns.get("bundle_version") == 1:
                self._migrate_installations_v2(connection)
            connection.execute("PRAGMA user_version = 2")
            connection.commit()
        os.chmod(self.path, 0o600)

    @staticmethod
    def _migrate_installations_v2(connection: sqlite3.Connection) -> None:
        # v1 made the iOS 27 runtime fields NOT NULL. They are legitimately
        # absent on iOS 18-26, so rebuild the table without weakening or losing
        # the existing key/session relationships. Foreign keys must be disabled
        # before the transaction while the parent table is swapped.
        connection.commit()
        connection.execute("PRAGMA foreign_keys = OFF")
        try:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(_INSTALLATIONS_V2_SCHEMA)
            connection.execute(
                """
                INSERT INTO installations_v2(
                    installation_id, key_id, public_key_der, receipt, app_id,
                    attest_environment, sign_count, validation_category,
                    bundle_version, attested_at, last_seen_at, revoked_at
                )
                SELECT installation_id, key_id, public_key_der, receipt, app_id,
                       attest_environment, sign_count, validation_category,
                       bundle_version, attested_at, last_seen_at, revoked_at
                FROM installations
                """
            )
            connection.execute("DROP TABLE installations")
            connection.execute("ALTER TABLE installations_v2 RENAME TO installations")
            if connection.execute("PRAGMA foreign_key_check").fetchone() is not None:
                raise RuntimeError("App Attest schema migration broke a foreign key.")
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.execute("PRAGMA foreign_keys = ON")

    def cleanup(self, *, now: int) -> None:
        with self._connection() as connection:
            connection.execute(
                """
                DELETE FROM sessions WHERE rowid IN (
                    SELECT rowid FROM sessions WHERE expires_at <= ? LIMIT 1000
                )
                """,
                (now,),
            )
            connection.execute(
                """
                DELETE FROM challenges WHERE rowid IN (
                    SELECT rowid FROM challenges WHERE expires_at <= ? LIMIT 1000
                )
                """,
                (now - 3600,),
            )
            connection.execute(
                """
                DELETE FROM rate_windows WHERE rowid IN (
                    SELECT rowid FROM rate_windows WHERE window_start < ? LIMIT 1000
                )
                """,
                (now - 86400,),
            )
            connection.commit()

    def consume_rate_limit(
        self,
        *,
        scope: str,
        subject_hash: str,
        limit: int,
        window_seconds: int,
        now: int,
    ) -> None:
        window_start = now - (now % window_seconds)
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                """
                SELECT request_count FROM rate_windows
                WHERE scope = ? AND subject_hash = ? AND window_start = ?
                """,
                (scope, subject_hash, window_start),
            ).fetchone()
            count = int(row["request_count"]) if row is not None else 0
            if count >= limit:
                connection.rollback()
                raise RateLimitExceeded(window_start + window_seconds - now)
            connection.execute(
                """
                INSERT INTO rate_windows(scope, subject_hash, window_start, request_count)
                VALUES (?, ?, ?, 1)
                ON CONFLICT(scope, subject_hash, window_start)
                DO UPDATE SET request_count = request_count + 1
                """,
                (scope, subject_hash, window_start),
            )
            connection.commit()

    def issue_challenge(
        self,
        *,
        challenge_id: str,
        secret: bytes,
        purpose: str,
        key_id: str | None,
        expires_at: int,
        client_ip_hash: str,
        now: int,
    ) -> None:
        with self._connection() as connection:
            connection.execute(
                """
                INSERT INTO challenges(
                    challenge_id, secret, purpose, key_id, expires_at, state,
                    client_ip_hash, created_at
                ) VALUES (?, ?, ?, ?, ?, 'issued', ?, ?)
                """,
                (
                    challenge_id,
                    secret,
                    purpose,
                    key_id,
                    expires_at,
                    client_ip_hash,
                    now,
                ),
            )
            connection.commit()

    def installation_for_key(self, key_id: str) -> InstallationRecord | None:
        with self._connection() as connection:
            row = connection.execute(
                """
                SELECT installation_id, key_id, public_key_der, receipt, app_id,
                       attest_environment, sign_count, validation_category,
                       bundle_version, revoked_at
                FROM installations WHERE key_id = ?
                """,
                (key_id,),
            ).fetchone()
        return self._installation(row)

    def claim_challenge(
        self,
        *,
        challenge_id: str,
        purpose: str,
        key_id: str | None,
        payload_hash: bytes,
        now: int,
    ) -> ChallengeClaim:
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT * FROM challenges WHERE challenge_id = ?",
                (challenge_id,),
            ).fetchone()
            if row is None:
                connection.rollback()
                raise StoreConflictError("unknown_challenge")
            challenge = self._challenge(row)
            if challenge.purpose != purpose or challenge.key_id != key_id:
                connection.rollback()
                raise StoreConflictError("challenge_mismatch")
            if challenge.expires_at <= now:
                connection.rollback()
                raise StoreConflictError("expired_challenge")
            if challenge.state == "completed":
                connection.rollback()
                raise StoreConflictError("challenge_already_used")
            if challenge.state != "issued":
                connection.rollback()
                raise StoreConflictError("challenge_already_used")
            connection.execute(
                """
                UPDATE challenges SET state = 'processing', payload_hash = ?
                WHERE challenge_id = ? AND state = 'issued'
                """,
                (payload_hash, challenge_id),
            )
            connection.commit()
            return ChallengeClaim(challenge=challenge)

    def fail_challenge(self, challenge_id: str) -> None:
        with self._connection() as connection:
            connection.execute(
                """
                UPDATE challenges SET state = 'failed'
                WHERE challenge_id = ? AND state = 'processing'
                """,
                (challenge_id,),
            )
            connection.commit()

    def complete_registration(
        self,
        *,
        challenge_id: str,
        installation_id: str,
        key_id: str,
        public_key_der: bytes,
        opaque_receipt: bytes,
        app_id: str,
        attest_environment: str,
        validation_category: int | None,
        bundle_version: str | None,
        session_id: str,
        token_hash: bytes,
        session_expires_at: int,
        now: int,
    ) -> SessionRecord:
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            existing = connection.execute(
                "SELECT 1 FROM installations WHERE key_id = ?",
                (key_id,),
            ).fetchone()
            if existing is not None:
                connection.rollback()
                raise StoreConflictError("app_attest_key_already_registered")
            connection.execute(
                """
                INSERT INTO installations(
                    installation_id, key_id, public_key_der, receipt, app_id,
                    attest_environment, sign_count, validation_category,
                    bundle_version, attested_at, last_seen_at
                ) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)
                """,
                (
                    installation_id,
                    key_id,
                    public_key_der,
                    opaque_receipt,
                    app_id,
                    attest_environment,
                    validation_category,
                    bundle_version,
                    now,
                    now,
                ),
            )
            self._insert_session(
                connection,
                session_id=session_id,
                installation_id=installation_id,
                token_hash=token_hash,
                expires_at=session_expires_at,
                now=now,
            )
            updated = connection.execute(
                """
                UPDATE challenges
                SET state = 'completed', completed_session_id = ?
                WHERE challenge_id = ? AND state = 'processing'
                """,
                (session_id, challenge_id),
            )
            if updated.rowcount != 1:
                connection.rollback()
                raise StoreConflictError("challenge_already_used")
            connection.commit()
        return SessionRecord(session_id, installation_id, session_expires_at)

    def complete_assertion(
        self,
        *,
        challenge_id: str,
        key_id: str,
        previous_sign_count: int,
        new_sign_count: int,
        validation_category: int | None,
        bundle_version: str | None,
        session_id: str,
        token_hash: bytes,
        session_expires_at: int,
        now: int,
    ) -> SessionRecord:
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            updated_key = connection.execute(
                """
                UPDATE installations
                SET sign_count = ?,
                    validation_category = COALESCE(?, validation_category),
                    bundle_version = COALESCE(?, bundle_version),
                    last_seen_at = ?
                WHERE key_id = ? AND sign_count = ? AND revoked_at IS NULL
                """,
                (
                    new_sign_count,
                    validation_category,
                    bundle_version,
                    now,
                    key_id,
                    previous_sign_count,
                ),
            )
            if updated_key.rowcount != 1:
                connection.rollback()
                raise StoreConflictError("assertion_counter_replay")
            row = connection.execute(
                "SELECT installation_id FROM installations WHERE key_id = ?",
                (key_id,),
            ).fetchone()
            if row is None:
                connection.rollback()
                raise StoreConflictError("unknown_app_attest_key")
            installation_id = str(row["installation_id"])
            self._insert_session(
                connection,
                session_id=session_id,
                installation_id=installation_id,
                token_hash=token_hash,
                expires_at=session_expires_at,
                now=now,
            )
            updated_challenge = connection.execute(
                """
                UPDATE challenges
                SET state = 'completed', completed_session_id = ?
                WHERE challenge_id = ? AND state = 'processing'
                """,
                (session_id, challenge_id),
            )
            if updated_challenge.rowcount != 1:
                connection.rollback()
                raise StoreConflictError("challenge_already_used")
            connection.commit()
        return SessionRecord(session_id, installation_id, session_expires_at)

    def authenticate_session(self, *, token_hash: bytes, now: int) -> InstallationRecord | None:
        with self._connection() as connection:
            row = connection.execute(
                """
                SELECT i.installation_id, i.key_id, i.public_key_der, i.receipt,
                       i.app_id, i.attest_environment, i.sign_count,
                       i.validation_category, i.bundle_version, i.revoked_at
                FROM sessions AS s
                JOIN installations AS i ON i.installation_id = s.installation_id
                WHERE s.token_hash = ? AND s.expires_at > ? AND s.revoked_at IS NULL
                """,
                (token_hash, now),
            ).fetchone()
            installation = self._installation(row)
            if installation is not None and installation.revoked_at is None:
                connection.execute(
                    "UPDATE installations SET last_seen_at = ? WHERE installation_id = ?",
                    (now, installation.installation_id),
                )
                connection.commit()
                return installation
        return None

    @staticmethod
    def _insert_session(
        connection: sqlite3.Connection,
        *,
        session_id: str,
        installation_id: str,
        token_hash: bytes,
        expires_at: int,
        now: int,
    ) -> None:
        connection.execute(
            """
            INSERT INTO sessions(
                session_id, installation_id, token_hash, expires_at, created_at
            ) VALUES (?, ?, ?, ?, ?)
            """,
            (session_id, installation_id, token_hash, expires_at, now),
        )

    @staticmethod
    def _challenge(row: sqlite3.Row) -> ChallengeRecord:
        return ChallengeRecord(
            challenge_id=str(row["challenge_id"]),
            secret=bytes(row["secret"]),
            purpose=str(row["purpose"]),
            key_id=str(row["key_id"]) if row["key_id"] is not None else None,
            expires_at=int(row["expires_at"]),
            state=str(row["state"]),
            payload_hash=bytes(row["payload_hash"]) if row["payload_hash"] is not None else None,
            completed_session_id=(
                str(row["completed_session_id"])
                if row["completed_session_id"] is not None
                else None
            ),
        )

    @staticmethod
    def _installation(row: sqlite3.Row | None) -> InstallationRecord | None:
        if row is None:
            return None
        return InstallationRecord(
            installation_id=str(row["installation_id"]),
            key_id=str(row["key_id"]),
            public_key_der=bytes(row["public_key_der"]),
            opaque_receipt=bytes(row["receipt"]),
            app_id=str(row["app_id"]),
            attest_environment=str(row["attest_environment"]),
            sign_count=int(row["sign_count"]),
            validation_category=(
                int(row["validation_category"])
                if row["validation_category"] is not None
                else None
            ),
            bundle_version=(
                str(row["bundle_version"])
                if row["bundle_version"] is not None
                else None
            ),
            revoked_at=int(row["revoked_at"]) if row["revoked_at"] is not None else None,
        )
