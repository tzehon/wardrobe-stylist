"""Privilege-drop and dedicated-volume safety checks for the production image."""

import ctypes
import json
import os
import stat
from pathlib import Path

import pytest

import container_entrypoint

BACKEND_ROOT = Path(__file__).resolve().parents[1]


def test_production_container_pins_payload_free_uvicorn_command() -> None:
    dockerfile = (BACKEND_ROOT / "Dockerfile").read_text(encoding="utf-8")
    entrypoint_lines = [
        line.removeprefix("ENTRYPOINT ")
        for line in dockerfile.splitlines()
        if line.startswith("ENTRYPOINT ")
    ]
    command_lines = [
        line.removeprefix("CMD ")
        for line in dockerfile.splitlines()
        if line.startswith("CMD ")
    ]

    assert len(entrypoint_lines) == 1
    assert json.loads(entrypoint_lines[0]) == ["python", "/app/container_entrypoint.py"]
    assert len(command_lines) == 1
    assert json.loads(command_lines[0]) == [
        "/app/.venv/bin/uvicorn",
        "app.main:app",
        "--host",
        "0.0.0.0",
        "--port",
        "8080",
        "--no-access-log",
    ]


def test_prepare_database_parent_creates_private_owned_directory(tmp_path: Path) -> None:
    data_root = tmp_path / "data"
    data_root.mkdir()
    database_path = data_root / "app-attest" / "auth.sqlite3"

    container_entrypoint.prepare_database_parent(
        database_path,
        uid=os.geteuid(),
        gid=os.getegid(),
        data_root=data_root,
    )

    metadata = database_path.parent.stat()
    assert stat.S_IMODE(metadata.st_mode) == 0o700
    assert metadata.st_uid == os.geteuid()
    assert metadata.st_gid == os.getegid()


def test_prepare_database_parent_secures_existing_sqlite_files(tmp_path: Path) -> None:
    data_root = tmp_path / "data"
    parent = data_root / "app-attest"
    parent.mkdir(parents=True)
    database_file = parent / "auth.sqlite3"
    database_sidecars = [
        database_file,
        parent / "auth.sqlite3-journal",
        parent / "auth.sqlite3-shm",
        parent / "auth.sqlite3-wal",
    ]
    for file in database_sidecars:
        file.write_bytes(b"sqlite-placeholder")
        file.chmod(0o644)

    container_entrypoint.prepare_database_parent(
        database_file,
        uid=os.geteuid(),
        gid=os.getegid(),
        data_root=data_root,
    )

    for file in database_sidecars:
        assert stat.S_IMODE(file.stat().st_mode) == 0o600


def test_prepare_database_parent_rejects_unexpected_regular_file(tmp_path: Path) -> None:
    data_root = tmp_path / "data"
    parent = data_root / "app-attest"
    parent.mkdir(parents=True)
    database_file = parent / "auth.sqlite3"
    database_file.write_bytes(b"sqlite-placeholder")
    (parent / "unrelated.txt").write_text("do not chown me")

    with pytest.raises(RuntimeError, match="unexpected entry"):
        container_entrypoint.prepare_database_parent(
            database_file,
            uid=os.geteuid(),
            gid=os.getegid(),
            data_root=data_root,
        )


def test_prepare_database_parent_rejects_database_hardlink(tmp_path: Path) -> None:
    data_root = tmp_path / "data"
    parent = data_root / "app-attest"
    parent.mkdir(parents=True)
    outside_file = data_root / "outside.sqlite3"
    outside_file.write_bytes(b"do not chown me")
    database_file = parent / "auth.sqlite3"
    os.link(outside_file, database_file)

    with pytest.raises(RuntimeError, match="multiple hard links"):
        container_entrypoint.prepare_database_parent(
            database_file,
            uid=os.geteuid(),
            gid=os.getegid(),
            data_root=data_root,
        )


def test_prepare_database_parent_rejects_fifo_without_blocking(tmp_path: Path) -> None:
    data_root = tmp_path / "data"
    parent = data_root / "app-attest"
    parent.mkdir(parents=True)
    database_file = parent / "auth.sqlite3"
    os.mkfifo(database_file)

    with pytest.raises(RuntimeError, match="unsafe entry"):
        container_entrypoint.prepare_database_parent(
            database_file,
            uid=os.geteuid(),
            gid=os.getegid(),
            data_root=data_root,
        )


@pytest.mark.parametrize("relative_path", ["auth.sqlite3", "../outside/auth.sqlite3"])
def test_prepare_database_parent_rejects_paths_not_strictly_below_data(
    tmp_path: Path,
    relative_path: str,
) -> None:
    data_root = tmp_path / "data"
    data_root.mkdir()

    with pytest.raises(RuntimeError, match="strictly below /data"):
        container_entrypoint.prepare_database_parent(
            data_root / relative_path,
            uid=os.geteuid(),
            gid=os.getegid(),
            data_root=data_root,
        )


def test_prepare_database_parent_rejects_symlink_traversal(tmp_path: Path) -> None:
    data_root = tmp_path / "data"
    outside = tmp_path / "outside"
    data_root.mkdir()
    outside.mkdir()
    (data_root / "app-attest").symlink_to(outside, target_is_directory=True)

    with pytest.raises(RuntimeError, match="symlinks|strictly below"):
        container_entrypoint.prepare_database_parent(
            data_root / "app-attest" / "auth.sqlite3",
            uid=os.geteuid(),
            gid=os.getegid(),
            data_root=data_root,
        )


def test_set_no_new_privileges_uses_linux_prctl(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[tuple[int, int, int, int, int]] = []

    class FakePrctl:
        argtypes: object = None
        restype: object = None

        def __call__(self, *args: int) -> int:
            calls.append(args)
            return 0

    class FakeLibC:
        prctl = FakePrctl()

    monkeypatch.setattr(container_entrypoint.sys, "platform", "linux")
    monkeypatch.setattr(
        container_entrypoint.ctypes,
        "CDLL",
        lambda _name, *, use_errno: FakeLibC(),
    )
    monkeypatch.setattr(container_entrypoint.ctypes, "set_errno", lambda _value: None)

    container_entrypoint.set_no_new_privileges()

    assert calls == [(container_entrypoint.PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0)]
    assert FakeLibC.prctl.argtypes == [
        ctypes.c_int,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
    ]
    assert FakeLibC.prctl.restype is ctypes.c_int


def test_main_drops_groups_gid_and_uid_before_exec(monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[tuple[str, object]] = []

    monkeypatch.setattr(
        container_entrypoint.os,
        "umask",
        lambda mask: calls.append(("umask", mask)),
    )
    monkeypatch.setattr(container_entrypoint.os, "geteuid", lambda: 0)
    monkeypatch.setattr(
        container_entrypoint.os,
        "setgroups",
        lambda groups: calls.append(("groups", groups)),
    )
    monkeypatch.setattr(
        container_entrypoint.os,
        "setgid",
        lambda gid: calls.append(("gid", gid)),
    )
    monkeypatch.setattr(
        container_entrypoint.os,
        "setuid",
        lambda uid: calls.append(("uid", uid)),
    )
    monkeypatch.setattr(
        container_entrypoint,
        "set_no_new_privileges",
        lambda: calls.append(("no_new_privileges", True)),
    )

    class Executed(Exception):
        pass

    def fake_execvp(command: str, argv: list[str]) -> None:
        calls.append(("exec", (command, argv)))
        raise Executed

    monkeypatch.setattr(container_entrypoint.os, "execvp", fake_execvp)
    monkeypatch.setenv("ENVIRONMENT", "dev")

    with pytest.raises(Executed):
        container_entrypoint.main(["container_entrypoint.py", "id", "-u"])

    assert calls == [
        ("umask", 0o077),
        ("groups", []),
        ("gid", container_entrypoint.SERVICE_GID),
        ("uid", container_entrypoint.SERVICE_UID),
        ("no_new_privileges", True),
        ("exec", ("id", ["id", "-u"])),
    ]
