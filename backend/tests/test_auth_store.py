"""Durability, replay, permissions, and bounded cleanup tests."""

import os
import sqlite3
import stat

import pytest

from app.auth.store import AuthStore, RateLimitExceeded, StoreConflictError


def test_store_is_private_durable_and_processing_replay_fails_closed(tmp_path) -> None:
    path = tmp_path / "private-auth" / "auth.sqlite3"
    first = AuthStore(path)
    first.initialize()
    first.issue_challenge(
        challenge_id="challenge-1",
        secret=b"c" * 32,
        purpose="attestation",
        key_id=None,
        expires_at=2000,
        now=1000,
    )

    assert stat.S_IMODE(os.stat(path.parent).st_mode) == 0o700
    assert stat.S_IMODE(os.stat(path).st_mode) == 0o600

    # A new process/store object sees the same challenge on disk.
    second = AuthStore(path)
    second.initialize()
    claim = second.claim_challenge(
        challenge_id="challenge-1",
        purpose="attestation",
        key_id=None,
        payload_hash=b"payload",
        now=1001,
    )
    assert claim.challenge.secret == b"c" * 32
    with pytest.raises(StoreConflictError, match="challenge_already_used"):
        first.claim_challenge(
            challenge_id="challenge-1",
            purpose="attestation",
            key_id=None,
            payload_hash=b"payload",
            now=1002,
        )


def test_v1_runtime_metadata_schema_migrates_without_losing_sessions(tmp_path) -> None:
    path = tmp_path / "private-auth" / "auth.sqlite3"
    path.parent.mkdir(mode=0o700)
    with sqlite3.connect(path) as connection:
        connection.executescript(
            """
            PRAGMA foreign_keys = ON;
            CREATE TABLE installations (
                installation_id TEXT PRIMARY KEY,
                key_id TEXT NOT NULL UNIQUE,
                public_key_der BLOB NOT NULL,
                receipt BLOB NOT NULL,
                app_id TEXT NOT NULL,
                attest_environment TEXT NOT NULL,
                sign_count INTEGER NOT NULL DEFAULT 0,
                validation_category INTEGER NOT NULL,
                bundle_version TEXT NOT NULL,
                attested_at INTEGER NOT NULL,
                last_seen_at INTEGER NOT NULL,
                revoked_at INTEGER
            );
            CREATE TABLE sessions (
                session_id TEXT PRIMARY KEY,
                installation_id TEXT NOT NULL REFERENCES installations(installation_id)
                    ON DELETE CASCADE,
                token_hash BLOB NOT NULL UNIQUE,
                expires_at INTEGER NOT NULL,
                created_at INTEGER NOT NULL,
                revoked_at INTEGER
            );
            PRAGMA user_version = 1;
            """
        )
        connection.execute(
            """
            INSERT INTO installations VALUES (
                'installation', 'key', ?, ?, 'PREFIX.bundle', 'development',
                4, 3, '7', 1000, 1001, NULL
            )
            """,
            (b"public", b"opaque-apple-receipt"),
        )
        connection.execute(
            """
            INSERT INTO sessions VALUES (
                'session', 'installation', ?, 2000, 1000, NULL
            )
            """,
            (b"token-hash",),
        )
        connection.commit()
    os.chmod(path, 0o600)

    store = AuthStore(path)
    store.initialize()

    with sqlite3.connect(path) as connection:
        columns = {
            row[1]: row[3]
            for row in connection.execute("PRAGMA table_info(installations)")
        }
        user_version = connection.execute("PRAGMA user_version").fetchone()[0]
        foreign_key_errors = connection.execute("PRAGMA foreign_key_check").fetchall()
    assert columns["validation_category"] == 0
    assert columns["bundle_version"] == 0
    assert user_version == 3
    assert foreign_key_errors == []

    installation = store.authenticate_session(token_hash=b"token-hash", now=1002)
    assert installation is not None
    assert installation.installation_id == "installation"
    assert installation.validation_category == 3
    assert installation.bundle_version == "7"


def test_v2_security_metadata_migrates_without_ip_hash_or_lost_challenge(tmp_path) -> None:
    path = tmp_path / "private-auth" / "auth.sqlite3"
    path.parent.mkdir(mode=0o700)
    with sqlite3.connect(path) as connection:
        connection.executescript(
            """
            CREATE TABLE challenges (
                challenge_id TEXT PRIMARY KEY,
                secret BLOB NOT NULL,
                purpose TEXT NOT NULL,
                key_id TEXT,
                expires_at INTEGER NOT NULL,
                state TEXT NOT NULL,
                payload_hash BLOB,
                completed_session_id TEXT,
                client_ip_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL
            );
            CREATE TABLE rate_windows (
                scope TEXT NOT NULL,
                subject_hash TEXT NOT NULL,
                window_start INTEGER NOT NULL,
                request_count INTEGER NOT NULL,
                PRIMARY KEY (scope, subject_hash, window_start)
            );
            INSERT INTO challenges VALUES (
                'migrated-challenge', X'0102', 'attestation', NULL, 1000,
                'issued', NULL, NULL, 'unused-pseudonymous-ip-hash', 100
            );
            INSERT INTO rate_windows VALUES ('challenge', 'subject', 120, 1);
            PRAGMA user_version = 2;
            """
        )
    os.chmod(path, 0o600)

    store = AuthStore(path)
    store.initialize()

    with sqlite3.connect(path) as connection:
        challenge_columns = {
            row[1] for row in connection.execute("PRAGMA table_info(challenges)")
        }
        rate_row = connection.execute(
            "SELECT expires_at, request_count FROM rate_windows"
        ).fetchone()
        rate_indexes = {
            row[1] for row in connection.execute("PRAGMA index_list(rate_windows)")
        }
        user_version = connection.execute("PRAGMA user_version").fetchone()[0]

    assert "client_ip_hash" not in challenge_columns
    assert rate_row == (180, 1)
    assert "rate_windows_expiry_idx" in rate_indexes
    assert user_version == 3
    claim = store.claim_challenge(
        challenge_id="migrated-challenge",
        purpose="attestation",
        key_id=None,
        payload_hash=b"payload",
        now=200,
    )
    assert claim.challenge.secret == b"\x01\x02"


def test_store_rejects_insecure_existing_database_directory_without_chmod(tmp_path) -> None:
    parent = tmp_path / "shared-directory"
    parent.mkdir(mode=0o755)
    os.chmod(parent, 0o755)

    with pytest.raises(PermissionError, match="permissions must be 0700"):
        AuthStore(parent / "auth.sqlite3").initialize()

    assert stat.S_IMODE(os.stat(parent).st_mode) == 0o755


def test_store_rejects_database_file_symlink_without_touching_target(tmp_path) -> None:
    parent = tmp_path / "private-auth"
    parent.mkdir(mode=0o700)
    target = tmp_path / "unrelated-secret"
    target.write_bytes(b"must-not-be-opened-as-sqlite")
    os.chmod(target, 0o600)
    database_path = parent / "auth.sqlite3"
    database_path.symlink_to(target)

    with pytest.raises(PermissionError, match="must not be a symlink"):
        AuthStore(database_path).initialize()

    assert target.read_bytes() == b"must-not-be-opened-as-sqlite"
    assert database_path.is_symlink()


def test_store_rejects_nonregular_database_path(tmp_path) -> None:
    parent = tmp_path / "private-auth"
    parent.mkdir(mode=0o700)
    database_path = parent / "auth.sqlite3"
    database_path.mkdir(mode=0o700)

    with pytest.raises(PermissionError, match="must be a regular file"):
        AuthStore(database_path).initialize()


def test_store_rejects_existing_database_with_unsafe_mode_without_chmod(tmp_path) -> None:
    parent = tmp_path / "private-auth"
    parent.mkdir(mode=0o700)
    database_path = parent / "auth.sqlite3"
    database_path.touch(mode=0o600)
    os.chmod(database_path, 0o640)

    with pytest.raises(PermissionError, match="permissions must be 0600"):
        AuthStore(database_path).initialize()

    assert stat.S_IMODE(os.stat(database_path).st_mode) == 0o640


def test_store_rejects_hardlinked_database_without_touching_other_name(tmp_path) -> None:
    parent = tmp_path / "private-auth"
    parent.mkdir(mode=0o700)
    other_name = parent / "unrelated-secret"
    other_name.write_bytes(b"must-not-be-opened-as-sqlite")
    os.chmod(other_name, 0o600)
    database_path = parent / "auth.sqlite3"
    os.link(other_name, database_path)

    with pytest.raises(PermissionError, match="additional hard links"):
        AuthStore(database_path).initialize()

    assert other_name.read_bytes() == b"must-not-be-opened-as-sqlite"
    assert os.stat(other_name).st_nlink == 2


def test_rate_window_is_atomic_and_reports_retry_after(tmp_path) -> None:
    store = AuthStore(tmp_path / "private-auth" / "auth.sqlite3")
    store.initialize()
    store.consume_rate_limit(
        scope="challenge",
        subject_hash="subject",
        limit=1,
        window_seconds=60,
        now=125,
    )
    with pytest.raises(RateLimitExceeded) as limited:
        store.consume_rate_limit(
            scope="challenge",
            subject_hash="subject",
            limit=1,
            window_seconds=60,
            now=126,
        )
    assert limited.value.retry_after == 54


def test_rate_window_admission_cap_allows_existing_subject_and_recovers_at_expiry(
    tmp_path,
) -> None:
    path = tmp_path / "private-auth" / "auth.sqlite3"
    store = AuthStore(path, max_active_rate_windows=2)
    store.initialize()
    for subject in ("first", "second"):
        store.consume_rate_limit(
            scope="challenge",
            subject_hash=subject,
            limit=10,
            window_seconds=60,
            now=125,
        )

    with pytest.raises(RateLimitExceeded) as at_capacity:
        store.consume_rate_limit(
            scope="challenge",
            subject_hash="third",
            limit=10,
            window_seconds=60,
            now=126,
        )
    assert at_capacity.value.retry_after == 54

    # Capacity protects admission of new subjects, but must not lock out an
    # already-admitted installation/IP during its current window.
    store.consume_rate_limit(
        scope="challenge",
        subject_hash="first",
        limit=10,
        window_seconds=60,
        now=126,
    )

    # Exact expiry plus cleanup on every admission reclaims capacity without a
    # process restart or a separate maintenance task.
    store.consume_rate_limit(
        scope="challenge",
        subject_hash="third",
        limit=10,
        window_seconds=60,
        now=180,
    )
    with sqlite3.connect(path) as connection:
        rows = connection.execute(
            "SELECT subject_hash, expires_at FROM rate_windows ORDER BY subject_hash"
        ).fetchall()
    assert rows == [("third", 240)]


def test_reserved_global_rate_bucket_cannot_be_starved_by_subject_admission_cap(
    tmp_path,
) -> None:
    path = tmp_path / "private-auth" / "auth.sqlite3"
    store = AuthStore(
        path,
        max_active_rate_windows=1,
        max_reserved_global_rate_windows=1,
    )
    store.initialize()
    store.consume_rate_limit(
        scope="challenge",
        subject_hash="attacker-ip",
        limit=10,
        window_seconds=60,
        now=125,
    )

    # The aggregate quota is the control that bounds distributed admission, so
    # its internal fixed-subject row must remain creatable after ordinary slots
    # are full. A second ordinary subject remains fail-closed.
    store.consume_rate_limit(
        scope="challenge-global",
        subject_hash="fixed-global-subject",
        limit=10,
        window_seconds=60,
        now=126,
        reserved_global_bucket=True,
    )
    with pytest.raises(RateLimitExceeded):
        store.consume_rate_limit(
            scope="registration-global",
            subject_hash="another-fixed-global-subject",
            limit=10,
            window_seconds=60,
            now=126,
            reserved_global_bucket=True,
        )
    with pytest.raises(RateLimitExceeded):
        store.consume_rate_limit(
            scope="challenge",
            subject_hash="another-attacker-ip",
            limit=10,
            window_seconds=60,
            now=126,
        )

    with sqlite3.connect(path) as connection:
        scopes = connection.execute(
            "SELECT scope FROM rate_windows ORDER BY scope"
        ).fetchall()
    assert scopes == [("challenge",), ("challenge-global",)]


def test_reserved_global_bucket_survives_legacy_ordinary_rows_over_new_cap(
    tmp_path,
) -> None:
    path = tmp_path / "private-auth" / "auth.sqlite3"
    legacy_store = AuthStore(path, max_active_rate_windows=3)
    legacy_store.initialize()
    for subject in ("legacy-first", "legacy-second"):
        legacy_store.consume_rate_limit(
            scope="challenge",
            subject_hash=subject,
            limit=10,
            window_seconds=60,
            now=125,
        )

    hardened_store = AuthStore(
        path,
        max_active_rate_windows=1,
        max_reserved_global_rate_windows=1,
    )
    hardened_store.consume_rate_limit(
        scope="challenge-global",
        subject_hash="fixed-global-subject",
        limit=10,
        window_seconds=60,
        now=126,
        reserved_global_bucket=True,
    )

    with sqlite3.connect(path) as connection:
        global_count = connection.execute(
            "SELECT COUNT(*) FROM rate_windows WHERE scope = 'challenge-global'"
        ).fetchone()[0]
    assert global_count == 1


def test_reserved_rate_bucket_requires_internal_global_scope(tmp_path) -> None:
    store = AuthStore(tmp_path / "private-auth" / "auth.sqlite3")
    store.initialize()

    with pytest.raises(ValueError, match="internal global scope"):
        store.consume_rate_limit(
            scope="challenge",
            subject_hash="subject",
            limit=1,
            window_seconds=60,
            now=125,
            reserved_global_bucket=True,
        )


def test_assertion_counter_update_is_compare_and_swap(tmp_path) -> None:
    store = AuthStore(tmp_path / "private-auth" / "auth.sqlite3")
    store.initialize()
    store.issue_challenge(
        challenge_id="register",
        secret=b"r" * 32,
        purpose="attestation",
        key_id=None,
        expires_at=2000,
        now=1000,
    )
    store.claim_challenge(
        challenge_id="register",
        purpose="attestation",
        key_id=None,
        payload_hash=b"register-payload",
        now=1000,
    )
    store.complete_registration(
        challenge_id="register",
        installation_id="installation",
        key_id="key",
        public_key_der=b"public",
        opaque_receipt=b"receipt",
        app_id="PREFIX.bundle",
        attest_environment="development",
        validation_category=3,
        bundle_version="7",
        session_id="registration-session",
        token_hash=b"registration-token-hash",
        session_expires_at=1900,
        now=1000,
    )

    for challenge_id in ("assertion-1", "assertion-2"):
        store.issue_challenge(
            challenge_id=challenge_id,
            secret=b"a" * 32,
            purpose="assertion",
            key_id="key",
            expires_at=2000,
            now=1001,
        )
        store.claim_challenge(
            challenge_id=challenge_id,
            purpose="assertion",
            key_id="key",
            payload_hash=challenge_id.encode(),
            now=1001,
        )

    store.complete_assertion(
        challenge_id="assertion-1",
        key_id="key",
        previous_sign_count=0,
        new_sign_count=1,
        validation_category=3,
        bundle_version="7",
        session_id="assertion-session-1",
        token_hash=b"assertion-token-hash-1",
        session_expires_at=1900,
        now=1001,
    )
    with pytest.raises(StoreConflictError, match="assertion_counter_replay"):
        store.complete_assertion(
            challenge_id="assertion-2",
            key_id="key",
            previous_sign_count=0,
            new_sign_count=1,
            validation_category=3,
            bundle_version="7",
            session_id="assertion-session-2",
            token_hash=b"assertion-token-hash-2",
            session_expires_at=1900,
            now=1002,
        )


def test_optional_runtime_metadata_upgrades_and_never_downgrades_to_null(tmp_path) -> None:
    store = AuthStore(tmp_path / "private-auth" / "auth.sqlite3")
    store.initialize()
    store.issue_challenge(
        challenge_id="register-without-runtime-extensions",
        secret=b"r" * 32,
        purpose="attestation",
        key_id=None,
        expires_at=2000,
        now=1000,
    )
    store.claim_challenge(
        challenge_id="register-without-runtime-extensions",
        purpose="attestation",
        key_id=None,
        payload_hash=b"register-payload",
        now=1000,
    )
    store.complete_registration(
        challenge_id="register-without-runtime-extensions",
        installation_id="legacy-core-installation",
        key_id="legacy-core-key",
        public_key_der=b"public",
        opaque_receipt=b"receipt",
        app_id="PREFIX.bundle",
        attest_environment="production",
        validation_category=None,
        bundle_version=None,
        session_id="registration-session",
        token_hash=b"registration-token-hash",
        session_expires_at=1900,
        now=1000,
    )

    installation = store.installation_for_key("legacy-core-key")
    assert installation is not None
    assert installation.validation_category is None
    assert installation.bundle_version is None

    for challenge_id, previous_count, new_count, category, bundle in (
        ("runtime-metadata-upgrade", 0, 1, 3, "7"),
        ("runtime-metadata-absent-later", 1, 2, None, None),
    ):
        store.issue_challenge(
            challenge_id=challenge_id,
            secret=b"a" * 32,
            purpose="assertion",
            key_id="legacy-core-key",
            expires_at=2000,
            now=1001,
        )
        store.claim_challenge(
            challenge_id=challenge_id,
            purpose="assertion",
            key_id="legacy-core-key",
            payload_hash=challenge_id.encode(),
            now=1001,
        )
        store.complete_assertion(
            challenge_id=challenge_id,
            key_id="legacy-core-key",
            previous_sign_count=previous_count,
            new_sign_count=new_count,
            validation_category=category,
            bundle_version=bundle,
            session_id=f"session-{new_count}",
            token_hash=f"token-{new_count}".encode(),
            session_expires_at=1900,
            now=1001,
        )

    upgraded = store.installation_for_key("legacy-core-key")
    assert upgraded is not None
    assert upgraded.sign_count == 2
    assert upgraded.validation_category == 3
    assert upgraded.bundle_version == "7"


def test_cleanup_is_bounded_and_preserves_active_challenge(tmp_path) -> None:
    path = tmp_path / "private-auth" / "auth.sqlite3"
    store = AuthStore(path)
    store.initialize()
    now = 10_000
    with sqlite3.connect(path) as connection:
        connection.executemany(
            """
            INSERT INTO challenges(
                challenge_id, secret, purpose, key_id, expires_at, state,
                created_at
            ) VALUES (?, ?, 'attestation', NULL, ?, 'issued', 1)
            """,
            [
                (f"expired-{index}", b"x" * 32, now - 4000)
                for index in range(1001)
            ],
        )
        connection.execute(
            """
            INSERT INTO challenges(
                challenge_id, secret, purpose, key_id, expires_at, state,
                created_at
            ) VALUES ('active', ?, 'attestation', NULL, ?, 'issued', ?)
            """,
            (b"a" * 32, now + 300, now),
        )
        connection.commit()

    store.cleanup(now=now)

    with sqlite3.connect(path) as connection:
        expired_count = connection.execute(
            "SELECT COUNT(*) FROM challenges WHERE challenge_id LIKE 'expired-%'"
        ).fetchone()[0]
        active_count = connection.execute(
            "SELECT COUNT(*) FROM challenges WHERE challenge_id = 'active'"
        ).fetchone()[0]
    assert expired_count == 1
    assert active_count == 1
