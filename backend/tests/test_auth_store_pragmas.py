"""Fail-closed checks for privacy-critical SQLite runtime settings."""

from __future__ import annotations

import sqlite3
from collections.abc import Sequence
from typing import Any

import pytest

import app.auth.store as store_module
from app.auth.store import AuthStore


class _SingleRowCursor:
    def __init__(self, value: object) -> None:
        self._value = value

    def fetchone(self) -> tuple[object]:
        return (self._value,)


class _PragmaOverrideConnection:
    """Delegate to SQLite while reporting one unsafe PRAGMA readback."""

    def __init__(
        self,
        connection: sqlite3.Connection,
        *,
        pragma_name: str,
        reported_value: object,
    ) -> None:
        self._connection = connection
        self._pragma_name = pragma_name
        self._reported_value = reported_value

    @property
    def row_factory(self) -> Any:
        return self._connection.row_factory

    @row_factory.setter
    def row_factory(self, value: Any) -> None:
        self._connection.row_factory = value

    def execute(
        self,
        statement: str,
        parameters: Sequence[object] = (),
    ) -> sqlite3.Cursor | _SingleRowCursor:
        normalized = " ".join(statement.strip().lower().split())
        if normalized == f"pragma {self._pragma_name}":
            return _SingleRowCursor(self._reported_value)
        return self._connection.execute(statement, parameters)

    def __getattr__(self, name: str) -> Any:
        return getattr(self._connection, name)


def _override_pragma_readback(
    monkeypatch: pytest.MonkeyPatch,
    *,
    pragma_name: str,
    reported_value: object,
) -> None:
    real_connect = sqlite3.connect

    def connect(*args: Any, **kwargs: Any) -> _PragmaOverrideConnection:
        return _PragmaOverrideConnection(
            real_connect(*args, **kwargs),
            pragma_name=pragma_name,
            reported_value=reported_value,
        )

    monkeypatch.setattr(store_module.sqlite3, "connect", connect)


def test_runtime_sqlite_initializes_persistent_wal_mode(tmp_path) -> None:
    path = tmp_path / "private-auth" / "auth.sqlite3"

    AuthStore(path).initialize()

    with sqlite3.connect(path) as connection:
        journal_mode = connection.execute("PRAGMA journal_mode").fetchone()[0]
    assert str(journal_mode).lower() == "wal"


@pytest.mark.parametrize(
    ("pragma_name", "reported_value", "required_value"),
    [
        ("foreign_keys", 0, "ON"),
        ("secure_delete", 0, "ON"),
        ("synchronous", 1, "FULL"),
        ("journal_mode", "delete", "WAL"),
    ],
)
def test_initialize_fails_closed_when_sqlite_rejects_required_pragma(
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
    pragma_name: str,
    reported_value: object,
    required_value: str,
) -> None:
    _override_pragma_readback(
        monkeypatch,
        pragma_name=pragma_name,
        reported_value=reported_value,
    )

    with pytest.raises(
        RuntimeError,
        match=rf"{pragma_name}={required_value}",
    ):
        AuthStore(tmp_path / "private-auth" / "auth.sqlite3").initialize()


@pytest.mark.parametrize(
    ("pragma_name", "reported_value", "required_value"),
    [
        ("foreign_keys", 0, "ON"),
        ("secure_delete", 0, "ON"),
        ("synchronous", 1, "FULL"),
    ],
)
def test_post_startup_store_connection_rechecks_connection_local_pragmas(
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
    pragma_name: str,
    reported_value: object,
    required_value: str,
) -> None:
    store = AuthStore(tmp_path / "private-auth" / "auth.sqlite3")
    store.initialize()
    _override_pragma_readback(
        monkeypatch,
        pragma_name=pragma_name,
        reported_value=reported_value,
    )

    with pytest.raises(
        RuntimeError,
        match=rf"{pragma_name}={required_value}",
    ):
        store.installation_for_key("missing")
