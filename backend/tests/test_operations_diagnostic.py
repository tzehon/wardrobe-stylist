"""The shipped diagnostic must inspect existing state without initializing it."""

import sqlite3
from pathlib import Path

import pytest

from app import operations_diagnostic as diagnostic
from app.auth.store import AuthStore


def test_diagnostic_reads_schema_and_runtime_without_changing_database(tmp_path: Path) -> None:
    database = tmp_path / "auth.sqlite3"
    AuthStore(database).initialize()
    before = database.read_bytes()
    processes = tmp_path / "proc"
    process = processes / "123"
    process.mkdir(parents=True)
    (process / "cmdline").write_bytes(
        b"/app/.venv/bin/uvicorn\0app.main:app\0--no-access-log\0"
        b"--log-config\0/app/uvicorn-logging.json\0"
    )
    (process / "status").write_text("Uid:\t10001\t10001\t10001\t10001\nNoNewPrivs:\t1\n")
    result = diagnostic.collect_diagnostic(database, process_root=processes, volume_path=tmp_path)
    for guard in (
        "exact_schema",
        "integrity_ok",
        "expected_tables",
        "expected_indexes",
        "process_runtime",
    ):
        assert result[guard] is True
    assert result["query_only"] == 1
    assert result["active_installations"] == result["active_sessions"] == 0
    assert database.read_bytes() == before
    assert str(database) not in str(result)
    (process / "status").write_text("Uid:\t0\t0\t0\t0\nNoNewPrivs:\t0\n")
    result = diagnostic.collect_diagnostic(database, process_root=processes, volume_path=tmp_path)
    assert result["process_runtime"] is False


def test_diagnostic_does_not_create_missing_database(tmp_path: Path) -> None:
    database = tmp_path / "missing.sqlite3"
    with pytest.raises(sqlite3.OperationalError):
        diagnostic.collect_diagnostic(database, process_root=tmp_path, volume_path=tmp_path)
    assert not database.exists()


def test_diagnostic_rejects_schema_drift(tmp_path: Path) -> None:
    database = tmp_path / "auth.sqlite3"
    AuthStore(database).initialize()
    with sqlite3.connect(database) as connection:
        connection.execute("CREATE TABLE unexpected (value TEXT)")
    result = diagnostic.collect_diagnostic(database, process_root=tmp_path, volume_path=tmp_path)
    assert result["exact_schema"] is False
    assert result["expected_tables"] is False


def test_cli_requires_service_identity(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(diagnostic.os, "getuid", lambda: 0)
    with pytest.raises(PermissionError, match="service_identity_required"):
        diagnostic.main()
