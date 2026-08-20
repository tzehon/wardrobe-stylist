"""Durable SQLite state for anonymous App Attest installations.

Only authentication metadata is stored: challenges, public keys, opaque Apple receipts,
monotonic assertion counters, short-lived session hashes, and coarse rate
windows. Wardrobe, prompt, and model-response payloads never enter this store.
"""

from __future__ import annotations

import os
import sqlite3
import stat
from collections.abc import Iterator, Sequence
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

# A normal single-user installation occupies only a handful of simultaneous
# scope/subject buckets. This ceiling leaves generous room for IP churn and
# recovery traffic while putting a small, deterministic bound on attacker-made
# rows in the public SQLite store.
MAX_ACTIVE_RATE_WINDOWS = 512
# Aggregate buckets are internal, fixed-subject sentinels that must remain
# admissible even if an attacker has already filled every ordinary IP/key slot.
# There are currently six such scopes; eight leaves two future slots while
# preserving a deterministic bound on active aggregate windows.
MAX_RESERVED_GLOBAL_RATE_WINDOWS = 8
# Valid deletion must remain possible even when attacker-controlled ordinary
# IP/key subjects have filled the general namespace. This separate bounded
# namespace covers deletion IP and proven-key buckets; its aggregate bucket
# continues to use the smaller fixed global namespace above.
MAX_RESERVED_DELETION_RATE_WINDOWS = 32

# These scopes were written by the retired receipt-extraction endpoint. Purge
# them at every startup so an in-place backend upgrade cannot leave a
# current-secret installation HMAC behind after that installation is deleted.
# This is migration cleanup only; no active admission path may create them.
_RETIRED_API_RATE_SCOPES = (
    "extract-global",
    "extract-installation",
    "extract-ip",
)

# Cleanup is deliberately bounded per transaction so a large restored backlog
# cannot hold the single production SQLite writer for one long transaction.
# ``cleanup`` repeats these short transactions until every eligible row is
# gone, so the bound never turns into an unbounded retention delay.
MAINTENANCE_BATCH_SIZE = 1000

CHALLENGE_POST_EXPIRY_RETENTION_SECONDS = 60 * 60
CHALLENGE_MAX_RETENTION_SECONDS = 70 * 60
SESSION_MAX_RETENTION_SECONDS = 20 * 60
RATE_WINDOW_MAX_GRACE_SECONDS = 5 * 60
INACTIVE_INSTALLATION_RETENTION_SECONDS = 90 * 24 * 60 * 60
REVOKED_INSTALLATION_RETENTION_SECONDS = 30 * 24 * 60 * 60


class StoreConflictError(RuntimeError):
    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class RateLimitExceeded(RuntimeError):
    def __init__(self, retry_after: int) -> None:
        super().__init__("rate_limit_exceeded")
        self.retry_after = max(1, retry_after)


class DeletionMaintenancePending(RuntimeError):
    """Logical deletion committed but its WAL checkpoint must be retried."""


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
    installation: InstallationRecord | None = None


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
class InstallationWritePolicy:
    """Installation identity and state required for one scoped write.

    ``installation_id`` binds a multi-step assertion or bearer flow to the
    exact installation row it previously read. This prevents a stale flow
    from attaching metadata to a later re-enrollment that happens to reuse the
    same App Attest key identifier.
    """

    installation_id: str | None
    app_id: str
    attest_environment: str
    allow_revoked: bool = False


@dataclass(frozen=True)
class SessionRecord:
    session_id: str
    installation_id: str
    expires_at: int


_SCHEMA = """
CREATE TABLE IF NOT EXISTS challenges (
    challenge_id TEXT PRIMARY KEY,
    secret BLOB NOT NULL,
    purpose TEXT NOT NULL CHECK (purpose IN ('attestation', 'assertion', 'deletion')),
    key_id TEXT,
    expires_at INTEGER NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('issued', 'processing', 'completed', 'failed')),
    payload_hash BLOB,
    completed_session_id TEXT,
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
    expires_at INTEGER NOT NULL,
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

_CHALLENGES_CURRENT_SCHEMA = """
CREATE TABLE challenges_current (
    challenge_id TEXT PRIMARY KEY,
    secret BLOB NOT NULL,
    purpose TEXT NOT NULL CHECK (purpose IN ('attestation', 'assertion', 'deletion')),
    key_id TEXT,
    expires_at INTEGER NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('issued', 'processing', 'completed', 'failed')),
    payload_hash BLOB,
    completed_session_id TEXT,
    created_at INTEGER NOT NULL
)
"""

_SESSIONS_CURRENT_SCHEMA = """
CREATE TABLE sessions (
    session_id TEXT PRIMARY KEY,
    installation_id TEXT NOT NULL REFERENCES installations(installation_id) ON DELETE CASCADE,
    token_hash BLOB NOT NULL UNIQUE,
    expires_at INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    revoked_at INTEGER
)
"""

_RATE_WINDOWS_CURRENT_SCHEMA = """
CREATE TABLE rate_windows (
    scope TEXT NOT NULL,
    subject_hash TEXT NOT NULL,
    window_start INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    request_count INTEGER NOT NULL,
    PRIMARY KEY (scope, subject_hash, window_start)
)
"""

# v2 added ``expires_at`` using ALTER TABLE. SQLite necessarily placed it
# after ``request_count`` and retained the migration-only DEFAULT. Its types,
# nullability, and composite primary key are equivalent to the current table,
# so it remains a recognized strict legacy layout.
_RATE_WINDOWS_V3_LEGACY_SCHEMA = """
CREATE TABLE rate_windows (
    scope TEXT NOT NULL,
    subject_hash TEXT NOT NULL,
    window_start INTEGER NOT NULL,
    request_count INTEGER NOT NULL,
    expires_at INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (scope, subject_hash, window_start)
)
"""


def _normalize_schema(sql: str) -> str:
    normalized = "".join(sql.lower().split())
    for delimiter in ('"', "`", "[", "]"):
        normalized = normalized.replace(delimiter, "")
    return normalized.replace("ifnotexists", "")


def _normalize_expected_schema(
    sql: str,
    *,
    declared_table: str,
    live_table: str,
) -> str:
    normalized = _normalize_schema(sql)
    declared_prefix = f"createtable{declared_table}("
    if not normalized.startswith(declared_prefix):
        raise ValueError("Expected schema did not begin with its declared table name.")
    return f"createtable{live_table}(" + normalized.removeprefix(declared_prefix)


_EXPECTED_AUTH_TABLE_SCHEMAS = {
    "challenges": frozenset(
        {
            _normalize_expected_schema(
                _CHALLENGES_CURRENT_SCHEMA,
                declared_table="challenges_current",
                live_table="challenges",
            )
        }
    ),
    "installations": frozenset(
        {
            _normalize_expected_schema(
                _INSTALLATIONS_V2_SCHEMA,
                declared_table="installations_v2",
                live_table="installations",
            )
        }
    ),
    "sessions": frozenset({_normalize_schema(_SESSIONS_CURRENT_SCHEMA)}),
    "rate_windows": frozenset(
        {
            _normalize_schema(_RATE_WINDOWS_CURRENT_SCHEMA),
            _normalize_schema(_RATE_WINDOWS_V3_LEGACY_SCHEMA),
        }
    ),
}

_EXPECTED_AUTH_COLUMN_SHAPES = {
    "challenges": frozenset(
        {
            (
                ("challenge_id", "TEXT", 0, None, 1),
                ("secret", "BLOB", 1, None, 0),
                ("purpose", "TEXT", 1, None, 0),
                ("key_id", "TEXT", 0, None, 0),
                ("expires_at", "INTEGER", 1, None, 0),
                ("state", "TEXT", 1, None, 0),
                ("payload_hash", "BLOB", 0, None, 0),
                ("completed_session_id", "TEXT", 0, None, 0),
                ("created_at", "INTEGER", 1, None, 0),
            )
        }
    ),
    "installations": frozenset(
        {
            (
                ("installation_id", "TEXT", 0, None, 1),
                ("key_id", "TEXT", 1, None, 0),
                ("public_key_der", "BLOB", 1, None, 0),
                ("receipt", "BLOB", 1, None, 0),
                ("app_id", "TEXT", 1, None, 0),
                ("attest_environment", "TEXT", 1, None, 0),
                ("sign_count", "INTEGER", 1, "0", 0),
                ("validation_category", "INTEGER", 0, None, 0),
                ("bundle_version", "TEXT", 0, None, 0),
                ("attested_at", "INTEGER", 1, None, 0),
                ("last_seen_at", "INTEGER", 1, None, 0),
                ("revoked_at", "INTEGER", 0, None, 0),
            )
        }
    ),
    "sessions": frozenset(
        {
            (
                ("session_id", "TEXT", 0, None, 1),
                ("installation_id", "TEXT", 1, None, 0),
                ("token_hash", "BLOB", 1, None, 0),
                ("expires_at", "INTEGER", 1, None, 0),
                ("created_at", "INTEGER", 1, None, 0),
                ("revoked_at", "INTEGER", 0, None, 0),
            )
        }
    ),
    "rate_windows": frozenset(
        {
            (
                ("scope", "TEXT", 1, None, 1),
                ("subject_hash", "TEXT", 1, None, 2),
                ("window_start", "INTEGER", 1, None, 3),
                ("expires_at", "INTEGER", 1, None, 0),
                ("request_count", "INTEGER", 1, None, 0),
            ),
            (
                ("scope", "TEXT", 1, None, 1),
                ("subject_hash", "TEXT", 1, None, 2),
                ("window_start", "INTEGER", 1, None, 3),
                ("request_count", "INTEGER", 1, None, 0),
                ("expires_at", "INTEGER", 1, "0", 0),
            ),
        }
    ),
}

_EXPECTED_AUTH_INDEX_SCHEMAS = {
    "sessions_token_hash_idx": _normalize_schema(
        "CREATE INDEX sessions_token_hash_idx ON sessions(token_hash)"
    ),
    "sessions_expiry_idx": _normalize_schema(
        "CREATE INDEX sessions_expiry_idx ON sessions(expires_at)"
    ),
    "challenges_expiry_idx": _normalize_schema(
        "CREATE INDEX challenges_expiry_idx ON challenges(expires_at)"
    ),
    "rate_windows_expiry_idx": _normalize_schema(
        "CREATE INDEX rate_windows_expiry_idx ON rate_windows(expires_at)"
    ),
    "installations_last_seen_idx": _normalize_schema(
        """
        CREATE INDEX installations_last_seen_idx
        ON installations(last_seen_at) WHERE revoked_at IS NULL
        """
    ),
    "installations_revoked_idx": _normalize_schema(
        """
        CREATE INDEX installations_revoked_idx
        ON installations(revoked_at) WHERE revoked_at IS NOT NULL
        """
    ),
}


class AuthStore:
    def __init__(
        self,
        path: Path,
        *,
        max_active_rate_windows: int = MAX_ACTIVE_RATE_WINDOWS,
        max_reserved_global_rate_windows: int = MAX_RESERVED_GLOBAL_RATE_WINDOWS,
        max_reserved_deletion_rate_windows: int = MAX_RESERVED_DELETION_RATE_WINDOWS,
    ) -> None:
        if max_active_rate_windows <= 0:
            raise ValueError("max_active_rate_windows must be positive")
        if max_reserved_global_rate_windows <= 0:
            raise ValueError("max_reserved_global_rate_windows must be positive")
        if max_reserved_deletion_rate_windows <= 0:
            raise ValueError("max_reserved_deletion_rate_windows must be positive")
        self.path = path
        self.max_active_rate_windows = max_active_rate_windows
        self.max_reserved_global_rate_windows = max_reserved_global_rate_windows
        self.max_reserved_deletion_rate_windows = max_reserved_deletion_rate_windows

    @contextmanager
    def _connection(self) -> Iterator[sqlite3.Connection]:
        self._ensure_private_directory()
        guard_fd = self._open_private_database_file()
        connection: sqlite3.Connection | None = None
        try:
            connection = sqlite3.connect(self.path, timeout=5.0)
            # SQLite accepts only a path, not the already-validated descriptor.
            # Keep that descriptor open and verify the pathname still resolves
            # to the same inode immediately after connect. The 0700 parent
            # prevents cross-user replacement during this narrow interval.
            guard_metadata = os.fstat(guard_fd)
            current_metadata = self.path.lstat()
            self._validate_private_database_file(current_metadata)
            if not self._same_file(guard_metadata, current_metadata):
                raise PermissionError("App Attest database changed while it was opened.")
            connection.row_factory = sqlite3.Row
            connection.execute("PRAGMA foreign_keys = ON")
            connection.execute("PRAGMA busy_timeout = 5000")
            connection.execute("PRAGMA synchronous = FULL")
            # Overwrite deleted cell content before the WAL checkpoint below.
            # This complements logical deletion without claiming byte erasure
            # from already-created encrypted volume snapshots.
            connection.execute("PRAGMA secure_delete = ON")
            self._verify_connection_security_pragmas(connection)
            yield connection
        finally:
            if connection is not None:
                connection.close()
            os.close(guard_fd)

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

    def _open_private_database_file(self) -> int:
        flags = os.O_RDWR | os.O_CREAT | os.O_EXCL
        flags |= getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
        try:
            descriptor = os.open(self.path, flags, 0o600)
        except FileExistsError:
            metadata = self.path.lstat()
            self._validate_private_database_file(metadata)
            existing_flags = os.O_RDWR
            existing_flags |= getattr(os, "O_CLOEXEC", 0) | getattr(os, "O_NOFOLLOW", 0)
            try:
                descriptor = os.open(self.path, existing_flags)
            except OSError as exc:
                raise PermissionError("App Attest database could not be opened safely.") from exc
            opened_metadata = os.fstat(descriptor)
            try:
                self._validate_private_database_file(opened_metadata)
                if not self._same_file(metadata, opened_metadata):
                    raise PermissionError("App Attest database changed while it was opened.")
            except Exception:
                os.close(descriptor)
                raise
            return descriptor
        except OSError as exc:
            raise PermissionError("App Attest database could not be created safely.") from exc

        try:
            os.fchmod(descriptor, 0o600)
            self._validate_private_database_file(os.fstat(descriptor))
        except Exception:
            os.close(descriptor)
            raise
        return descriptor

    @staticmethod
    def _validate_private_database_file(metadata: os.stat_result) -> None:
        if stat.S_ISLNK(metadata.st_mode):
            raise PermissionError("App Attest database must not be a symlink.")
        if not stat.S_ISREG(metadata.st_mode):
            raise PermissionError("App Attest database must be a regular file.")
        if metadata.st_uid != os.geteuid():
            raise PermissionError("App Attest database must be owned by this process.")
        if stat.S_IMODE(metadata.st_mode) != 0o600:
            raise PermissionError("App Attest database permissions must be 0600.")
        if metadata.st_nlink != 1:
            raise PermissionError("App Attest database must not have additional hard links.")

    @staticmethod
    def _same_file(first: os.stat_result, second: os.stat_result) -> bool:
        return first.st_dev == second.st_dev and first.st_ino == second.st_ino

    @staticmethod
    def _require_integer_pragma(
        connection: sqlite3.Connection,
        *,
        name: str,
        expected: int,
        expected_label: str,
    ) -> None:
        row = connection.execute(f"PRAGMA {name}").fetchone()
        actual = None if row is None else row[0]
        if actual != expected:
            raise RuntimeError(
                f"App Attest SQLite requires {name}={expected_label}; got {actual!r}."
            )

    @classmethod
    def _verify_connection_security_pragmas(
        cls,
        connection: sqlite3.Connection,
    ) -> None:
        # These settings are connection-local. Setting a PRAGMA can be ignored
        # by SQLite (for example when it is attempted from an invalid state),
        # so merely issuing the assignment is not a security guarantee.
        cls._require_integer_pragma(
            connection,
            name="foreign_keys",
            expected=1,
            expected_label="ON",
        )
        cls._require_integer_pragma(
            connection,
            name="secure_delete",
            expected=1,
            expected_label="ON",
        )
        cls._require_integer_pragma(
            connection,
            name="synchronous",
            expected=2,
            expected_label="FULL",
        )

    @staticmethod
    def _verify_wal_journal_mode(connection: sqlite3.Connection) -> None:
        row = connection.execute("PRAGMA journal_mode").fetchone()
        actual = None if row is None else str(row[0]).lower()
        if actual != "wal":
            raise RuntimeError(
                f"App Attest SQLite requires journal_mode=WAL; got {actual!r}."
            )

    def initialize(self) -> None:
        with self._connection() as connection:
            connection.execute("PRAGMA journal_mode = WAL")
            self._verify_wal_journal_mode(connection)
            user_version = int(connection.execute("PRAGMA user_version").fetchone()[0])
            if user_version > 4:
                raise RuntimeError(
                    "App Attest database schema is newer than this backend supports."
                )
            connection.executescript(_SCHEMA)
            columns = {
                str(row["name"]): int(row["notnull"])
                for row in connection.execute("PRAGMA table_info(installations)")
            }
            if columns.get("validation_category") == 1 or columns.get("bundle_version") == 1:
                self._migrate_installations_v2(connection)
            challenge_columns = {
                str(row["name"])
                for row in connection.execute("PRAGMA table_info(challenges)")
            }
            if "client_ip_hash" in challenge_columns:
                self._migrate_challenges_v3(connection)
            challenge_schema = str(
                connection.execute(
                    "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = 'challenges'"
                ).fetchone()["sql"]
            )
            if "'deletion'" not in challenge_schema:
                self._migrate_challenges_v4(connection)
            rate_columns = {
                str(row["name"])
                for row in connection.execute("PRAGMA table_info(rate_windows)")
            }
            if "expires_at" not in rate_columns:
                self._migrate_rate_windows_v3(connection)
            connection.executemany(
                "DELETE FROM rate_windows WHERE scope = ?",
                ((scope,) for scope in _RETIRED_API_RATE_SCOPES),
            )
            connection.execute(
                "CREATE INDEX IF NOT EXISTS challenges_expiry_idx ON challenges(expires_at)"
            )
            connection.execute(
                "CREATE INDEX IF NOT EXISTS rate_windows_expiry_idx ON rate_windows(expires_at)"
            )
            connection.execute(
                """
                CREATE INDEX IF NOT EXISTS installations_last_seen_idx
                ON installations(last_seen_at) WHERE revoked_at IS NULL
                """
            )
            connection.execute(
                """
                CREATE INDEX IF NOT EXISTS installations_revoked_idx
                ON installations(revoked_at) WHERE revoked_at IS NOT NULL
                """
            )
            self._verify_expected_auth_schema(connection)
            connection.execute("PRAGMA user_version = 4")
            # The v1 migration temporarily disables foreign keys while it
            # swaps the parent table. Verify the complete connection policy a
            # second time before startup can report success.
            self._verify_connection_security_pragmas(connection)
            self._verify_wal_journal_mode(connection)
            connection.commit()

    @staticmethod
    def _verify_expected_auth_schema(connection: sqlite3.Connection) -> None:
        tables = {
            str(row[0])
            for row in connection.execute(
                """
                SELECT name FROM sqlite_schema
                WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
                """
            )
        }
        if tables != set(_EXPECTED_AUTH_TABLE_SCHEMAS):
            raise RuntimeError("App Attest database contains unexpected auth tables.")
        unexpected_objects = connection.execute(
            """
            SELECT type, name FROM sqlite_schema
            WHERE type IN ('trigger', 'view') AND name NOT LIKE 'sqlite_%'
            LIMIT 1
            """
        ).fetchone()
        if unexpected_objects is not None:
            raise RuntimeError(
                "App Attest database contains an unexpected trigger or view."
            )

        user_indexes = {
            str(row["name"]): str(row["sql"])
            for row in connection.execute(
                """
                SELECT name, sql FROM sqlite_schema
                WHERE type = 'index' AND name NOT LIKE 'sqlite_%'
                """
            )
        }
        if set(user_indexes) != set(_EXPECTED_AUTH_INDEX_SCHEMAS):
            raise RuntimeError("App Attest database contains unexpected auth indexes.")
        for index_name, expected_schema in _EXPECTED_AUTH_INDEX_SCHEMAS.items():
            if _normalize_schema(user_indexes[index_name]) != expected_schema:
                raise RuntimeError(
                    f"App Attest database index {index_name} has an unexpected schema."
                )

        for table, allowed_schemas in _EXPECTED_AUTH_TABLE_SCHEMAS.items():
            schema_row = connection.execute(
                "SELECT sql FROM sqlite_schema WHERE type = 'table' AND name = ?",
                (table,),
            ).fetchone()
            schema_sql = None if schema_row is None else schema_row["sql"]
            if not isinstance(schema_sql, str) or _normalize_schema(schema_sql) not in (
                allowed_schemas
            ):
                raise RuntimeError(
                    f"App Attest database table {table} has an unexpected schema."
                )
            actual_shape = tuple(
                (
                    str(row["name"]),
                    str(row["type"]).upper(),
                    int(row["notnull"]),
                    str(row["dflt_value"]) if row["dflt_value"] is not None else None,
                    int(row["pk"]),
                )
                for row in connection.execute(f"PRAGMA table_info({table})")
            )
            if actual_shape not in _EXPECTED_AUTH_COLUMN_SHAPES[table]:
                raise RuntimeError(
                    f"App Attest database table {table} has unsafe column constraints."
                )

        if not AuthStore._has_unique_index(connection, "installations", ("key_id",)):
            raise RuntimeError("App Attest installations.key_id must remain UNIQUE.")
        if not AuthStore._has_unique_index(connection, "sessions", ("token_hash",)):
            raise RuntimeError("App Attest sessions.token_hash must remain UNIQUE.")

        session_foreign_keys = {
            (
                str(row["table"]),
                str(row["from"]),
                str(row["to"]),
                str(row["on_update"]).upper(),
                str(row["on_delete"]).upper(),
                str(row["match"]).upper(),
            )
            for row in connection.execute("PRAGMA foreign_key_list(sessions)")
        }
        expected_session_foreign_key = {
            (
                "installations",
                "installation_id",
                "installation_id",
                "NO ACTION",
                "CASCADE",
                "NONE",
            )
        }
        if session_foreign_keys != expected_session_foreign_key:
            raise RuntimeError(
                "App Attest sessions must cascade from installations."
            )
        if connection.execute("PRAGMA foreign_key_check").fetchone() is not None:
            raise RuntimeError("App Attest database contains broken foreign keys.")

    @staticmethod
    def _has_unique_index(
        connection: sqlite3.Connection,
        table: str,
        columns: tuple[str, ...],
    ) -> bool:
        for index in connection.execute(f"PRAGMA index_list({table})"):
            if int(index["unique"]) != 1 or int(index["partial"]) != 0:
                continue
            index_name = str(index["name"]).replace('"', '""')
            indexed_columns = tuple(
                str(row["name"])
                for row in connection.execute(f'PRAGMA index_info("{index_name}")')
            )
            if indexed_columns == columns:
                return True
        return False

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

    @staticmethod
    def _migrate_challenges_v3(connection: sqlite3.Connection) -> None:
        # The original schema retained a pseudonymous client-IP hash on each
        # challenge even though admission control already lives in rate_windows
        # and the value was never read. Rebuild atomically to preserve every
        # in-flight challenge while dropping that unnecessary identifier.
        connection.commit()
        try:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(_CHALLENGES_CURRENT_SCHEMA)
            connection.execute(
                """
                INSERT INTO challenges_current(
                    challenge_id, secret, purpose, key_id, expires_at, state,
                    payload_hash, completed_session_id, created_at
                )
                SELECT challenge_id, secret, purpose, key_id, expires_at, state,
                       payload_hash, completed_session_id, created_at
                FROM challenges
                """
            )
            connection.execute("DROP TABLE challenges")
            connection.execute("ALTER TABLE challenges_current RENAME TO challenges")
            connection.commit()
        except Exception:
            connection.rollback()
            raise

    @staticmethod
    def _migrate_challenges_v4(connection: sqlite3.Connection) -> None:
        # v4 adds a one-time deletion assertion purpose. Rebuild the table
        # atomically because SQLite cannot alter an existing CHECK constraint.
        connection.commit()
        try:
            connection.execute("BEGIN IMMEDIATE")
            connection.execute(_CHALLENGES_CURRENT_SCHEMA)
            connection.execute(
                """
                INSERT INTO challenges_current(
                    challenge_id, secret, purpose, key_id, expires_at, state,
                    payload_hash, completed_session_id, created_at
                )
                SELECT challenge_id, secret, purpose, key_id, expires_at, state,
                       payload_hash, completed_session_id, created_at
                FROM challenges
                """
            )
            connection.execute("DROP TABLE challenges")
            connection.execute("ALTER TABLE challenges_current RENAME TO challenges")
            connection.commit()
        except Exception:
            connection.rollback()
            raise

    @staticmethod
    def _migrate_rate_windows_v3(connection: sqlite3.Connection) -> None:
        # v2 retained rate rows for a coarse day because their individual
        # expiry was not stored. Add exact expiry so admission capacity is
        # reclaimed as soon as a window closes. All existing non-challenge
        # scopes are one-hour windows.
        connection.execute(
            "ALTER TABLE rate_windows ADD COLUMN expires_at INTEGER NOT NULL DEFAULT 0"
        )
        connection.execute(
            """
            UPDATE rate_windows
            SET expires_at = window_start +
                CASE WHEN scope IN ('challenge', 'challenge-global') THEN 60 ELSE 3600 END
            WHERE expires_at = 0
            """
        )

    def cleanup(self, *, now: int, deadline_lookahead_seconds: int = 0) -> None:
        if not 0 <= deadline_lookahead_seconds <= RATE_WINDOW_MAX_GRACE_SECONDS:
            raise ValueError("deadline_lookahead_seconds must be between 0 and 300")
        with self._connection() as connection:
            self._delete_until_drained(
                connection,
                """
                DELETE FROM sessions WHERE rowid IN (
                    SELECT rowid FROM sessions
                    WHERE expires_at <= ? OR created_at <= ?
                    LIMIT ?
                )
                """,
                (
                    now,
                    now
                    - (SESSION_MAX_RETENTION_SECONDS - deadline_lookahead_seconds),
                    MAINTENANCE_BATCH_SIZE,
                ),
            )
            self._delete_until_drained(
                connection,
                """
                DELETE FROM challenges WHERE rowid IN (
                    SELECT rowid FROM challenges
                    WHERE expires_at <= ? OR created_at <= ?
                    LIMIT ?
                )
                """,
                (
                    now - CHALLENGE_POST_EXPIRY_RETENTION_SECONDS,
                    now
                    - (CHALLENGE_MAX_RETENTION_SECONDS - deadline_lookahead_seconds),
                    MAINTENANCE_BATCH_SIZE,
                ),
            )
            self._delete_until_drained(
                connection,
                """
                DELETE FROM rate_windows WHERE rowid IN (
                    SELECT rowid FROM rate_windows
                    WHERE expires_at <= ?
                    LIMIT ?
                )
                """,
                (now, MAINTENANCE_BATCH_SIZE),
            )
            self._delete_installations_until_drained(
                connection,
                revoked=True,
                cutoff=(
                    now
                    - REVOKED_INSTALLATION_RETENTION_SECONDS
                    + deadline_lookahead_seconds
                ),
            )
            self._delete_installations_until_drained(
                connection,
                revoked=False,
                cutoff=(
                    now
                    - INACTIVE_INSTALLATION_RETENTION_SECONDS
                    + deadline_lookahead_seconds
                ),
            )
            self._checkpoint_and_truncate_wal(connection)

    @staticmethod
    def _delete_until_drained(
        connection: sqlite3.Connection,
        statement: str,
        parameters: tuple[int, ...],
    ) -> None:
        while True:
            connection.execute("BEGIN IMMEDIATE")
            try:
                deleted = connection.execute(statement, parameters).rowcount
                connection.commit()
            except Exception:
                connection.rollback()
                raise
            if deleted < MAINTENANCE_BATCH_SIZE:
                return

    @staticmethod
    def _delete_installations_until_drained(
        connection: sqlite3.Connection,
        *,
        revoked: bool,
        cutoff: int,
    ) -> None:
        while True:
            connection.execute("BEGIN IMMEDIATE")
            try:
                if revoked:
                    key_rows = connection.execute(
                        """
                        SELECT key_id FROM installations
                        WHERE revoked_at IS NOT NULL AND revoked_at <= ?
                        LIMIT ?
                        """,
                        (cutoff, MAINTENANCE_BATCH_SIZE),
                    ).fetchall()
                else:
                    key_rows = connection.execute(
                        """
                        SELECT key_id FROM installations
                        WHERE revoked_at IS NULL AND last_seen_at <= ?
                        LIMIT ?
                        """,
                        (cutoff, MAINTENANCE_BATCH_SIZE),
                    ).fetchall()
                if not key_rows:
                    connection.commit()
                    return
                key_ids = [(str(row["key_id"]),) for row in key_rows]
                connection.executemany(
                    "DELETE FROM challenges WHERE key_id = ?",
                    key_ids,
                )
                deleted = connection.executemany(
                    "DELETE FROM installations WHERE key_id = ?",
                    key_ids,
                ).rowcount
                connection.commit()
            except Exception:
                connection.rollback()
                raise
            if deleted < MAINTENANCE_BATCH_SIZE:
                return

    @staticmethod
    def _checkpoint_and_truncate_wal(connection: sqlite3.Connection) -> None:
        row = connection.execute("PRAGMA wal_checkpoint(TRUNCATE)").fetchone()
        if row is None or int(row[0]) != 0:
            raise RuntimeError("App Attest WAL checkpoint could not complete.")

    def checkpoint_and_truncate_wal(self) -> None:
        """Finish privacy maintenance before reporting an idempotent deletion.

        Installation deletion commits its logical row removal before SQLite can
        checkpoint the WAL. If that checkpoint is temporarily busy, a retry
        must perform the same maintenance before the service may report that
        the already-absent identity is fully deleted.
        """
        with self._connection() as connection:
            try:
                self._checkpoint_and_truncate_wal(connection)
            except Exception as exc:
                raise DeletionMaintenancePending(
                    "App Attest deletion WAL maintenance is still pending."
                ) from exc

    def consume_rate_limit(
        self,
        *,
        scope: str,
        subject_hash: str,
        limit: int,
        window_seconds: int,
        now: int,
        reserved_global_bucket: bool = False,
        reserved_deletion_bucket: bool = False,
    ) -> None:
        if reserved_global_bucket and reserved_deletion_bucket:
            raise ValueError("A rate bucket may use only one reserved namespace.")
        if reserved_global_bucket and not scope.endswith("-global"):
            raise ValueError("Reserved rate buckets must use an internal global scope.")
        if reserved_deletion_bucket and not scope.startswith("deletion-"):
            raise ValueError("Reserved deletion buckets must use a deletion scope.")
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            try:
                self._consume_rate_limit_in_transaction(
                    connection,
                    scope=scope,
                    subject_hash=subject_hash,
                    limit=limit,
                    window_seconds=window_seconds,
                    now=now,
                    reserved_global_bucket=reserved_global_bucket,
                    reserved_deletion_bucket=reserved_deletion_bucket,
                )
            except RateLimitExceeded:
                # Preserve the opportunistic expired-row cleanup even when
                # the current bucket has no remaining capacity.
                connection.commit()
                raise
            else:
                connection.commit()

    def consume_installation_rate_limit(
        self,
        *,
        scope: str,
        subject_hash: str,
        limit: int,
        window_seconds: int,
        now: int,
        key_id: str | None = None,
        installation_id: str | None = None,
        policy: InstallationWritePolicy,
        reserved_deletion_bucket: bool = False,
    ) -> None:
        """Charge a key/installation quota only while its owner still exists.

        Validation and the rate-window upsert share one ``BEGIN IMMEDIATE``
        transaction. Whichever transaction linearizes last therefore decides
        the outcome: a successful deletion removes an earlier rate row, while
        a later writer sees the installation as absent and cannot recreate it.
        """
        if (key_id is None) == (installation_id is None):
            raise ValueError("Exactly one installation lookup key is required.")
        if policy.installation_id is None:
            raise ValueError("Installation rate policy must bind an installation id.")
        if scope.endswith("-global"):
            raise ValueError("Installation rate buckets cannot use a global scope.")
        if reserved_deletion_bucket and not scope.startswith("deletion-"):
            raise ValueError("Reserved deletion buckets must use a deletion scope.")

        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            try:
                self._validate_scoped_installation(
                    connection,
                    key_id=key_id,
                    installation_id=installation_id,
                    policy=policy,
                )
                self._consume_rate_limit_in_transaction(
                    connection,
                    scope=scope,
                    subject_hash=subject_hash,
                    limit=limit,
                    window_seconds=window_seconds,
                    now=now,
                    reserved_global_bucket=False,
                    reserved_deletion_bucket=reserved_deletion_bucket,
                )
            except RateLimitExceeded:
                connection.commit()
                raise
            except Exception:
                connection.rollback()
                raise
            else:
                connection.commit()

    def _consume_rate_limit_in_transaction(
        self,
        connection: sqlite3.Connection,
        *,
        scope: str,
        subject_hash: str,
        limit: int,
        window_seconds: int,
        now: int,
        reserved_global_bucket: bool,
        reserved_deletion_bucket: bool,
    ) -> None:
        window_start = now - (now % window_seconds)
        expires_at = window_start + window_seconds
        connection.execute(
            """
            DELETE FROM rate_windows WHERE rowid IN (
                SELECT rowid FROM rate_windows
                WHERE expires_at <= ? LIMIT 1000
            )
            """,
            (now,),
        )
        row = connection.execute(
            """
            SELECT request_count FROM rate_windows
            WHERE scope = ? AND subject_hash = ? AND window_start = ?
            """,
            (scope, subject_hash, window_start),
        ).fetchone()
        count = int(row["request_count"]) if row is not None else 0
        if count >= limit:
            raise RateLimitExceeded(window_start + window_seconds - now)
        if row is None:
            if reserved_global_bucket:
                # Count the bounded internal namespace independently. This
                # keeps aggregate protection admissible even when a legacy
                # database already contains more ordinary rows than the new
                # cap; ordinary rows still age out on their exact expiry.
                active_count = int(
                    connection.execute(
                        """
                        SELECT COUNT(*) FROM rate_windows
                        WHERE expires_at > ? AND scope LIKE '%-global'
                        """,
                        (now,),
                    ).fetchone()[0]
                )
                admission_limit = self.max_reserved_global_rate_windows
                earliest_expiry_query = """
                    SELECT MIN(expires_at) FROM rate_windows
                    WHERE expires_at > ? AND scope LIKE '%-global'
                """
            elif reserved_deletion_bucket:
                active_count = int(
                    connection.execute(
                        """
                        SELECT COUNT(*) FROM rate_windows
                        WHERE expires_at > ? AND scope LIKE 'deletion-%'
                          AND scope NOT LIKE '%-global'
                        """,
                        (now,),
                    ).fetchone()[0]
                )
                admission_limit = self.max_reserved_deletion_rate_windows
                earliest_expiry_query = """
                    SELECT MIN(expires_at) FROM rate_windows
                    WHERE expires_at > ? AND scope LIKE 'deletion-%'
                      AND scope NOT LIKE '%-global'
                """
            else:
                active_count = int(
                    connection.execute(
                        "SELECT COUNT(*) FROM rate_windows WHERE expires_at > ?",
                        (now,),
                    ).fetchone()[0]
                )
                admission_limit = self.max_active_rate_windows
                earliest_expiry_query = (
                    "SELECT MIN(expires_at) FROM rate_windows WHERE expires_at > ?"
                )
            if active_count >= admission_limit:
                earliest_expiry = connection.execute(
                    earliest_expiry_query,
                    (now,),
                ).fetchone()[0]
                retry_after = (
                    int(earliest_expiry) - now
                    if earliest_expiry is not None
                    else window_seconds
                )
                raise RateLimitExceeded(retry_after)
        connection.execute(
            """
            INSERT INTO rate_windows(
                scope, subject_hash, window_start, expires_at, request_count
            )
            VALUES (?, ?, ?, ?, 1)
            ON CONFLICT(scope, subject_hash, window_start)
            DO UPDATE SET
                request_count = request_count + 1,
                expires_at = excluded.expires_at
            """,
            (scope, subject_hash, window_start, expires_at),
        )

    def issue_challenge(
        self,
        *,
        challenge_id: str,
        secret: bytes,
        purpose: str,
        key_id: str | None,
        expires_at: int,
        now: int,
        policy: InstallationWritePolicy | None = None,
    ) -> None:
        if (key_id is None) != (policy is None):
            raise ValueError("Key-bound challenges require an installation write policy.")
        if policy is not None and policy.installation_id is None:
            raise ValueError("Key-bound challenge policy must bind an installation id.")
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            try:
                if key_id is not None and policy is not None:
                    self._validate_scoped_installation(
                        connection,
                        key_id=key_id,
                        installation_id=None,
                        policy=policy,
                    )
                connection.execute(
                    """
                    INSERT INTO challenges(
                        challenge_id, secret, purpose, key_id, expires_at, state,
                        created_at
                    ) VALUES (?, ?, ?, ?, ?, 'issued', ?)
                    """,
                    (
                        challenge_id,
                        secret,
                        purpose,
                        key_id,
                        expires_at,
                        now,
                    ),
                )
                connection.commit()
            except Exception:
                connection.rollback()
                raise

    @classmethod
    def _validate_scoped_installation(
        cls,
        connection: sqlite3.Connection,
        *,
        key_id: str | None,
        installation_id: str | None,
        policy: InstallationWritePolicy,
    ) -> InstallationRecord:
        if (key_id is None) == (installation_id is None):
            raise ValueError("Exactly one installation lookup key is required.")
        if key_id is not None:
            row = connection.execute(
                """
                SELECT installation_id, key_id, public_key_der, receipt, app_id,
                       attest_environment, sign_count, validation_category,
                       bundle_version, revoked_at
                FROM installations WHERE key_id = ?
                """,
                (key_id,),
            ).fetchone()
        else:
            row = connection.execute(
                """
                SELECT installation_id, key_id, public_key_der, receipt, app_id,
                       attest_environment, sign_count, validation_category,
                       bundle_version, revoked_at
                FROM installations WHERE installation_id = ?
                """,
                (installation_id,),
            ).fetchone()
        installation = cls._installation(row)
        if (
            installation is None
            or (
                policy.installation_id is not None
                and installation.installation_id != policy.installation_id
            )
        ):
            raise StoreConflictError("unknown_app_attest_key")
        if (
            installation.app_id != policy.app_id
            or installation.attest_environment != policy.attest_environment
        ):
            raise StoreConflictError("configuration_mismatch")
        if installation.revoked_at is not None and not policy.allow_revoked:
            raise StoreConflictError("revoked_app_attest_key")
        return installation

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
        policy: InstallationWritePolicy | None = None,
    ) -> ChallengeClaim:
        if (key_id is None) != (policy is None):
            raise ValueError("Key-bound challenges require an installation write policy.")
        if policy is not None and policy.installation_id is None:
            raise ValueError("Key-bound challenge policy must bind an installation id.")
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT * FROM challenges WHERE challenge_id = ?",
                (challenge_id,),
            ).fetchone()
            if row is None:
                if purpose == "deletion" and key_id is not None and policy is not None:
                    # Another deletion may have removed the installation and
                    # every key-bound challenge while this proof was in
                    # flight. Surface the absent identity so the service runs
                    # its idempotent WAL-maintenance path; if the installation
                    # still exists this remains an ordinary unknown challenge.
                    self._validate_scoped_installation(
                        connection,
                        key_id=key_id,
                        installation_id=None,
                        policy=policy,
                    )
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
            installation = None
            if key_id is not None and policy is not None:
                installation = self._validate_scoped_installation(
                    connection,
                    key_id=key_id,
                    installation_id=None,
                    policy=policy,
                )
            connection.execute(
                """
                UPDATE challenges SET state = 'processing', payload_hash = ?
                WHERE challenge_id = ? AND state = 'issued'
                """,
                (payload_hash, challenge_id),
            )
            connection.commit()
            return ChallengeClaim(challenge=challenge, installation=installation)

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
                SET state = 'completed', completed_session_id = ?, key_id = ?
                WHERE challenge_id = ? AND state = 'processing'
                """,
                (session_id, key_id, challenge_id),
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
        policy: InstallationWritePolicy,
    ) -> SessionRecord:
        if policy.installation_id is None:
            raise ValueError("Assertion policy must bind an installation id.")
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            installation = self._validate_scoped_installation(
                connection,
                key_id=key_id,
                installation_id=None,
                policy=policy,
            )
            updated_key = connection.execute(
                """
                UPDATE installations
                SET sign_count = ?,
                    validation_category = COALESCE(?, validation_category),
                    bundle_version = COALESCE(?, bundle_version),
                    last_seen_at = ?
                WHERE installation_id = ? AND key_id = ?
                  AND sign_count = ? AND revoked_at IS NULL
                """,
                (
                    new_sign_count,
                    validation_category,
                    bundle_version,
                    now,
                    installation.installation_id,
                    key_id,
                    previous_sign_count,
                ),
            )
            if updated_key.rowcount != 1:
                connection.rollback()
                raise StoreConflictError("assertion_counter_replay")
            self._insert_session(
                connection,
                session_id=session_id,
                installation_id=installation.installation_id,
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
        return SessionRecord(
            session_id,
            installation.installation_id,
            session_expires_at,
        )

    def complete_installation_deletion(
        self,
        *,
        challenge_id: str,
        key_id: str,
        installation_id: str,
        previous_sign_count: int,
        rate_subject_hashes: Sequence[tuple[str, str]],
        policy: InstallationWritePolicy,
    ) -> None:
        """Atomically delete an assertion-proven anonymous installation.

        The compare-and-swap counter closes the race with ordinary assertion
        renewal. Sessions cascade through the foreign key; key-bound
        challenges and only the supplied key/installation rate subjects are
        removed explicitly. IP and aggregate buckets age out normally.
        """
        allowed_rate_scopes = {
            "session-key",
            "deletion-key",
            "recommend-installation",
        }
        if any(scope not in allowed_rate_scopes for scope, _ in rate_subject_hashes):
            raise ValueError("Deletion may remove only key/installation rate subjects.")
        if policy.installation_id != installation_id or not policy.allow_revoked:
            raise ValueError("Deletion policy must bind the deletable installation.")

        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            try:
                challenge = connection.execute(
                    """
                    SELECT 1 FROM challenges
                    WHERE challenge_id = ? AND purpose = 'deletion'
                      AND key_id = ? AND state = 'processing'
                    """,
                    (challenge_id, key_id),
                ).fetchone()
                if challenge is None:
                    connection.rollback()
                    raise StoreConflictError("challenge_already_used")
                installation = self._validate_scoped_installation(
                    connection,
                    key_id=key_id,
                    installation_id=None,
                    policy=policy,
                )
                if installation.sign_count != previous_sign_count:
                    connection.rollback()
                    raise StoreConflictError("assertion_counter_replay")

                connection.execute("DELETE FROM challenges WHERE key_id = ?", (key_id,))
                for scope, subject_hash in rate_subject_hashes:
                    connection.execute(
                        "DELETE FROM rate_windows WHERE scope = ? AND subject_hash = ?",
                        (scope, subject_hash),
                    )
                deleted = connection.execute(
                    """
                    DELETE FROM installations
                    WHERE installation_id = ? AND key_id = ? AND sign_count = ?
                    """,
                    (installation_id, key_id, previous_sign_count),
                )
                if deleted.rowcount != 1:
                    connection.rollback()
                    raise StoreConflictError("assertion_counter_replay")
                connection.commit()
            except StoreConflictError:
                raise
            except Exception:
                connection.rollback()
                raise
            try:
                self._checkpoint_and_truncate_wal(connection)
            except Exception as exc:
                raise DeletionMaintenancePending(
                    "App Attest deletion WAL maintenance is still pending."
                ) from exc

    def authenticate_session(
        self,
        *,
        token_hash: bytes,
        now: int,
        policy: InstallationWritePolicy,
    ) -> InstallationRecord | None:
        if policy.installation_id is not None:
            raise ValueError("Bearer lookup policy must derive the installation id.")
        with self._connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
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
            if installation is None:
                connection.commit()
                return None
            installation = self._validate_scoped_installation(
                connection,
                key_id=None,
                installation_id=installation.installation_id,
                policy=policy,
            )
            updated = connection.execute(
                """
                UPDATE installations SET last_seen_at = ?
                WHERE installation_id = ?
                """,
                (now, installation.installation_id),
            )
            if updated.rowcount != 1:
                connection.rollback()
                raise StoreConflictError("unknown_app_attest_key")
            connection.commit()
            return installation

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
