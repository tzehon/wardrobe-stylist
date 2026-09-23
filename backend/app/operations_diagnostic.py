"""Payload-free, read-only production auth/storage diagnostics.

Invoked by the operations verifier as the service user. Keep output limited to
schema/runtime guards and aggregate counts; never expose stored identities.
"""

import json
import os
import sqlite3
import stat
import time
from contextlib import closing
from pathlib import Path
from urllib.parse import quote

from app.auth.store import AuthStore

_ACTIVE_SESSION_MEMBERSHIP_QUERY = """
SELECT COUNT(*) FROM sessions AS s
LEFT JOIN installations AS i ON i.installation_id = s.installation_id
WHERE s.revoked_at IS NULL AND s.expires_at > ?
  AND (i.installation_id IS NULL OR i.revoked_at IS NOT NULL)
"""


def collect_diagnostic(
    database: Path,
    *,
    process_root: Path = Path("/proc"),
    volume_path: Path = Path("/data"),
) -> dict[str, object]:
    uri = "file:" + quote(str(database), safe="/") + "?mode=ro"
    with closing(sqlite3.connect(uri, uri=True)) as connection:
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA query_only=ON")
        connection.execute("PRAGMA foreign_keys=ON")
        now = int(time.time())
        tables = {
            str(row[0])
            for row in connection.execute(
                "SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'"
            )
        }
        indexes = {
            str(row[0])
            for row in connection.execute(
                "SELECT name FROM sqlite_schema WHERE type='index' AND name NOT LIKE 'sqlite_%'"
            )
        }
        unexpected_objects = connection.execute(
            "SELECT COUNT(*) FROM sqlite_schema "
            "WHERE type IN ('trigger','view') AND name NOT LIKE 'sqlite_%'"
        ).fetchone()[0]
        try:
            AuthStore._verify_expected_auth_schema(connection)
            exact_schema = True
        except (RuntimeError, sqlite3.Error):
            exact_schema = False
        database_stat = database.stat()
        parent_stat = database.parent.stat()
        runtime_processes = []
        for process_path in process_root.iterdir():
            if not process_path.name.isdigit():
                continue
            try:
                candidate_command = (process_path / "cmdline").read_bytes().replace(b"\x00", b" ")
            except OSError:
                continue
            if (
                b"/app/.venv/bin/uvicorn" in candidate_command
                and b"app.main:app" in candidate_command
            ):
                runtime_processes.append((process_path, candidate_command))
        process_status = (
            (runtime_processes[0][0] / "status").read_text(encoding="utf-8")
            if len(runtime_processes) == 1
            else ""
        )
        process_command = runtime_processes[0][1] if len(runtime_processes) == 1 else b""
        process_uid = any(
            line.split()[1:] == ["10001", "10001", "10001", "10001"]
            for line in process_status.splitlines()
            if line.startswith("Uid:")
        )
        process_no_new_privileges = any(
            line.split()[1:] == ["1"]
            for line in process_status.splitlines()
            if line.startswith("NoNewPrivs:")
        )
        process_uvicorn = b"uvicorn" in process_command and b"app.main:app" in process_command
        process_no_access_log = b"--no-access-log" in process_command
        process_logging_config = b"/app/uvicorn-logging.json" in process_command
        filesystem = os.statvfs(volume_path)
        total_bytes = filesystem.f_blocks * filesystem.f_frsize
        available_bytes = filesystem.f_bavail * filesystem.f_frsize
        used_percent = (
            100.0 if total_bytes <= 0 else (total_bytes - available_bytes) * 100 / total_bytes
        )
        result = {
            "diagnostic_version": 1,
            "query_only": connection.execute("PRAGMA query_only").fetchone()[0],
            "foreign_keys": connection.execute("PRAGMA foreign_keys").fetchone()[0],
            "secure_delete": connection.execute("PRAGMA secure_delete").fetchone()[0],
            "synchronous": connection.execute("PRAGMA synchronous").fetchone()[0],
            "journal_mode": str(connection.execute("PRAGMA journal_mode").fetchone()[0]).lower(),
            "schema_version": connection.execute("PRAGMA user_version").fetchone()[0],
            "integrity_ok": connection.execute("PRAGMA integrity_check").fetchone()[0] == "ok",
            "foreign_key_errors": len(connection.execute("PRAGMA foreign_key_check").fetchall()),
            "expected_tables": tables
            == {"challenges", "installations", "rate_windows", "sessions"},
            "expected_indexes": indexes
            == {
                "challenges_expiry_idx",
                "installations_last_seen_idx",
                "installations_revoked_idx",
                "rate_windows_expiry_idx",
                "sessions_expiry_idx",
                "sessions_token_hash_idx",
            },
            "exact_schema": exact_schema,
            "unexpected_objects": unexpected_objects,
            "database_security": (
                stat.S_ISREG(database_stat.st_mode)
                and database_stat.st_nlink == 1
                and database_stat.st_uid == 10001
                and database_stat.st_gid == 10001
                and stat.S_IMODE(database_stat.st_mode) == 0o600
                and parent_stat.st_uid == 10001
                and parent_stat.st_gid == 10001
                and stat.S_IMODE(parent_stat.st_mode) == 0o700
                and not database.is_symlink()
                and not database.parent.is_symlink()
            ),
            "process_runtime": (
                len(runtime_processes) == 1
                and process_uid
                and process_no_new_privileges
                and process_uvicorn
                and process_no_access_log
                and process_logging_config
            ),
            "process_uid": process_uid,
            "process_no_new_privileges": process_no_new_privileges,
            "process_uvicorn": process_uvicorn,
            "process_no_access_log": process_no_access_log,
            "process_logging_config": process_logging_config,
            "active_installations": connection.execute(
                "SELECT COUNT(*) FROM installations WHERE revoked_at IS NULL"
            ).fetchone()[0],
            "active_sessions": connection.execute(
                "SELECT COUNT(*) FROM sessions WHERE revoked_at IS NULL AND expires_at > ?",
                (now,),
            ).fetchone()[0],
            "invalid_active_session_memberships": connection.execute(
                _ACTIVE_SESSION_MEMBERSHIP_QUERY, (now,)
            ).fetchone()[0],
            "pending_challenges": connection.execute(
                "SELECT COUNT(*) FROM challenges "
                "WHERE state IN ('issued','processing') AND expires_at > ?",
                (now,),
            ).fetchone()[0],
            "failed_challenges": connection.execute(
                "SELECT COUNT(*) FROM challenges WHERE state='failed'"
            ).fetchone()[0],
            "rate_windows": connection.execute(
                "SELECT COUNT(*) FROM rate_windows WHERE expires_at > ?", (now,)
            ).fetchone()[0],
            "used_percent": used_percent,
        }
        return result


def main() -> None:
    if (os.getuid(), os.geteuid(), os.getgid(), os.getegid()) != (10001,) * 4:
        raise PermissionError("service_identity_required")
    result = collect_diagnostic(Path(os.environ["APP_ATTEST_DATABASE_PATH"]))
    print(json.dumps(result, separators=(",", ":")))


if __name__ == "__main__":
    main()
