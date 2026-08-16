#!/usr/bin/env python3
"""Prepare the private Fly auth volume, drop privileges, and exec the command."""

from __future__ import annotations

import ctypes
import os
import stat
import sys
from pathlib import Path
from typing import NoReturn

SERVICE_UID = 10001
SERVICE_GID = 10001
PRODUCTION_DATA_ROOT = Path("/data")
PR_SET_NO_NEW_PRIVS = 38


def set_no_new_privileges() -> None:
    """Prevent this process and its descendants from gaining exec privileges."""
    if sys.platform != "linux":
        raise RuntimeError("the production container privilege guard requires Linux")

    libc = ctypes.CDLL(None, use_errno=True)
    prctl = libc.prctl
    prctl.argtypes = [
        ctypes.c_int,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
        ctypes.c_ulong,
    ]
    prctl.restype = ctypes.c_int

    ctypes.set_errno(0)
    if prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0:
        error_number = ctypes.get_errno()
        raise OSError(error_number, os.strerror(error_number))


def prepare_database_parent(
    database_path: Path,
    *,
    uid: int = SERVICE_UID,
    gid: int = SERVICE_GID,
    data_root: Path = PRODUCTION_DATA_ROOT,
) -> None:
    """Secure one dedicated database directory strictly below the mounted data root."""
    if not database_path.is_absolute():
        raise RuntimeError("production App Attest database path must be absolute")

    try:
        resolved_root = data_root.resolve(strict=True)
    except OSError as error:
        raise RuntimeError("production data root is not mounted") from error

    parent = database_path.parent
    lexical_parent = Path(os.path.abspath(parent))
    resolved_parent = parent.resolve(strict=False)
    if resolved_parent == resolved_root or not resolved_parent.is_relative_to(resolved_root):
        raise RuntimeError("production App Attest database parent must be strictly below /data")
    if lexical_parent != resolved_parent:
        raise RuntimeError("production App Attest database parent must not traverse symlinks")

    parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if parent.is_symlink() or parent.resolve(strict=True) != resolved_parent:
        raise RuntimeError("production App Attest database parent must not be a symlink")

    database_name = database_path.name
    if database_name in {"", ".", ".."}:
        raise RuntimeError("production App Attest database path must name a file")
    allowed_names = {
        database_name,
        f"{database_name}-journal",
        f"{database_name}-shm",
        f"{database_name}-wal",
    }

    # A first non-root rollout may inherit root-owned SQLite state from the
    # prior image. Open everything relative to an O_NOFOLLOW directory fd so a
    # path cannot be swapped to a symlink between validation and mutation.
    directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC | os.O_NOFOLLOW
    directory_fd = os.open(parent, directory_flags)
    try:
        with os.scandir(directory_fd) as entries:
            for entry in entries:
                if entry.name not in allowed_names:
                    raise RuntimeError(
                        "production App Attest database directory contains "
                        "an unexpected entry"
                    )

                # O_NONBLOCK prevents a restored FIFO/device with an allowed
                # SQLite name from hanging privileged startup before fstat can
                # reject it.
                file_flags = (
                    os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK
                )
                file_fd = os.open(entry.name, file_flags, dir_fd=directory_fd)
                try:
                    metadata = os.fstat(file_fd)
                    if not stat.S_ISREG(metadata.st_mode):
                        raise RuntimeError(
                            "production App Attest database directory contains "
                            "an unsafe entry"
                        )
                    if metadata.st_nlink != 1:
                        raise RuntimeError(
                            "production App Attest database files must not have "
                            "multiple hard links"
                        )
                    os.fchown(file_fd, uid, gid)
                    os.fchmod(file_fd, 0o600)
                finally:
                    os.close(file_fd)

        os.fchown(directory_fd, uid, gid)
        os.fchmod(directory_fd, 0o700)
    finally:
        os.close(directory_fd)


def main(argv: list[str]) -> NoReturn:
    if len(argv) < 2:
        raise SystemExit("container entrypoint requires a command")

    os.umask(0o077)
    if os.geteuid() == 0:
        if os.environ.get("ENVIRONMENT", "").strip().lower() == "production":
            raw_database_path = os.environ.get("APP_ATTEST_DATABASE_PATH", "").strip()
            if not raw_database_path:
                raise RuntimeError("production APP_ATTEST_DATABASE_PATH is required")
            prepare_database_parent(Path(raw_database_path))

        os.setgroups([])
        os.setgid(SERVICE_GID)
        os.setuid(SERVICE_UID)

    set_no_new_privileges()

    # Docker supplies an argv array. Preserve it exactly and never introduce a
    # shell or string interpolation at this privilege boundary.
    os.execvp(argv[1], argv[1:])  # nosec B606


if __name__ == "__main__":
    main(sys.argv)
