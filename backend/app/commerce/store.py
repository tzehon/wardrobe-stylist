"""Inactive, metadata-only commerce persistence. No route imports this module.

All owner/period inputs come from a future trusted verification service, NOT
request bodies. This store does not prove Apple ownership or provider outcomes.
Provisioning/retention approval and cross-store recovery are activation gates.
"""

from __future__ import annotations

import os
import secrets
import sqlite3
import stat
import time
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path

from app.commerce.usage import AllowancePeriod, Operation, Outcome, UsageBucket, UsageError
from app.schemas.commerce import MAX_REVISION, MAX_TIMESTAMP, Plan

MAX_OWNERS = 1000
MAX_PERIODS_PER_OWNER = 128
MAX_OPERATIONS_PER_PERIOD = 256
HANDLE_TTL = 300
_APPLICATION_ID = 0x57434D31
_SCHEMA = """
CREATE TABLE owners (
    owner TEXT PRIMARY KEY,
    active_period TEXT,
    observed_at INTEGER NOT NULL,
    revision INTEGER NOT NULL CHECK(revision >= 0 AND revision <= 9007199254740991)
);
CREATE TABLE periods (
    owner TEXT NOT NULL REFERENCES owners(owner),
    period TEXT NOT NULL,
    plan TEXT NOT NULL CHECK(plan IN ('free', 'plus')),
    start INTEGER NOT NULL,
    end INTEGER NOT NULL CHECK(end > start),
    verified_until INTEGER NOT NULL,
    revoked INTEGER NOT NULL DEFAULT 0 CHECK(revoked IN (0, 1)),
    PRIMARY KEY(owner, period),
    UNIQUE(owner, plan, start, end)
);
CREATE TABLE operations (
    id TEXT PRIMARY KEY,
    owner TEXT NOT NULL,
    period TEXT NOT NULL,
    expires_at INTEGER NOT NULL,
    state TEXT NOT NULL CHECK(state IN ('issued', 'reserved', 'dispatched', 'succeeded', 'failed')),
    credited INTEGER NOT NULL DEFAULT 0 CHECK(credited IN (0, 1)),
    FOREIGN KEY(owner, period) REFERENCES periods(owner, period),
    CHECK(credited = 0 OR state = 'succeeded')
);
CREATE UNIQUE INDEX one_pending_owner ON operations(owner)
    WHERE state IN ('reserved', 'dispatched');
CREATE UNIQUE INDEX one_credit_period ON operations(owner, period) WHERE credited = 1;
CREATE INDEX period_operations ON operations(owner, period);
"""
_EXPECTED_SCHEMA = frozenset(" ".join(sql.split()) for sql in _SCHEMA.split(";") if sql.strip())


class CommerceStoreError(RuntimeError):
    """Fixed error codes; never echo identifiers or database contents."""


def _private(path: Path) -> None:
    parent, file = path.parent.lstat(), path.lstat()
    if (not stat.S_ISDIR(parent.st_mode) or stat.S_IMODE(parent.st_mode) != 0o700
            or parent.st_uid != os.geteuid() or not stat.S_ISREG(file.st_mode)
            or stat.S_IMODE(file.st_mode) != 0o600 or file.st_uid != os.geteuid()
            or file.st_nlink != 1):
        raise CommerceStoreError("storage_not_private")


def initialize_commerce_database(path: Path) -> None:
    """Explicit first provisioning only; NEVER use this to recover lost storage.

    No runtime or deployment calls this. Only temporary fixture stores are
    authorized until retention/privacy and provisioning have been reviewed.
    An interrupted initializer leaves an invalid file, never an automatic retry.
    """
    path = path.absolute()
    connection = None
    try:
        parent = path.parent.lstat()
        if (not stat.S_ISDIR(parent.st_mode) or stat.S_IMODE(parent.st_mode) != 0o700
                or parent.st_uid != os.geteuid()):
            raise CommerceStoreError("storage_not_private")
        descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        os.close(descriptor)
        connection = sqlite3.connect(path.as_uri() + "?mode=rw", uri=True)
        connection.execute("PRAGMA journal_mode=WAL")
        connection.execute("PRAGMA synchronous=FULL")
        connection.executescript(_SCHEMA)
        connection.execute(f"PRAGMA application_id={_APPLICATION_ID}")
        connection.execute("PRAGMA user_version=1")
        connection.commit()
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    except (OSError, sqlite3.Error) as exc:
        raise CommerceStoreError("provisioning_failed") from exc
    finally:
        if connection is not None:
            connection.close()


@dataclass(frozen=True)
class StoredOperation:
    operation_id: str
    period_id: str
    state: str
    delivery_credited: bool


class CommerceStore:
    def __init__(self, path: Path, *, clock: Callable[[], int] | None = None) -> None:
        self.path = path.absolute()
        self.clock = clock or (lambda: int(time.time()))

    @contextmanager
    def _transaction(self) -> Iterator[tuple[sqlite3.Connection, int]]:
        connection = None
        descriptor = None
        try:
            _private(self.path)
            descriptor = os.open(self.path, os.O_RDWR | os.O_NOFOLLOW)
            before = os.fstat(descriptor)
            connection = sqlite3.connect(
                self.path.as_uri() + "?mode=rw", uri=True, timeout=5,
            )
            _private(self.path)
            after = self.path.lstat()
            if (before.st_ino, before.st_dev) != (after.st_ino, after.st_dev):
                raise CommerceStoreError("storage_changed")
            connection.row_factory = sqlite3.Row
            connection.execute("PRAGMA foreign_keys=ON")
            connection.execute("PRAGMA synchronous=FULL")
            if (connection.execute("PRAGMA application_id").fetchone()[0] != _APPLICATION_ID
                    or connection.execute("PRAGMA user_version").fetchone()[0] != 1
                    or connection.execute("PRAGMA journal_mode").fetchone()[0] != "wal"
                    or connection.execute("PRAGMA synchronous").fetchone()[0] != 2):
                raise CommerceStoreError("storage_schema_invalid")
            connection.execute("BEGIN IMMEDIATE")
            schema = frozenset(" ".join(row[0].split()) for row in connection.execute(
                "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL",
            ))
            if schema != _EXPECTED_SCHEMA:
                raise CommerceStoreError("storage_schema_invalid")
            now = self.clock()
            if type(now) is not int or not 0 <= now <= MAX_TIMESTAMP:
                raise CommerceStoreError("clock_invalid")
            yield connection, now
            connection.commit()
        except (OSError, sqlite3.Error) as exc:
            raise CommerceStoreError("storage_unavailable") from exc
        finally:
            if connection is not None:
                connection.close()  # rolls back any failed transaction
            if descriptor is not None:
                os.close(descriptor)

    @staticmethod
    def _owner(db: sqlite3.Connection, owner: str, now: int) -> sqlite3.Row:
        row: sqlite3.Row | None = db.execute(
            "SELECT * FROM owners WHERE owner=?", (owner,),
        ).fetchone()
        if row is None:
            raise UsageError("operation_not_found")
        if now < row["observed_at"]:
            raise UsageError("clock_regression")
        db.execute("UPDATE owners SET observed_at=? WHERE owner=?", (now, owner))
        return row  # revision/active period unchanged by observation alone

    @staticmethod
    def _bump(db: sqlite3.Connection, owner: str) -> None:
        if db.execute(
            "UPDATE owners SET revision=revision+1 WHERE owner=? AND revision < ?",
            (owner, MAX_REVISION),
        ).rowcount != 1:
            raise CommerceStoreError("revision_exhausted")

    @staticmethod
    def _period(db: sqlite3.Connection, owner: str, period: str) -> sqlite3.Row:
        row: sqlite3.Row | None = db.execute(
            "SELECT * FROM periods WHERE owner=? AND period=?", (owner, period),
        ).fetchone()
        if row is None:
            raise UsageError("operation_not_found")
        return row

    @staticmethod
    def _usable(owner: sqlite3.Row, period: sqlite3.Row, now: int) -> None:
        if (owner["active_period"] != period["period"] or period["revoked"]
                or not period["start"] <= now < min(period["end"], period["verified_until"])):
            raise UsageError("entitlement_unavailable")

    @staticmethod
    def _bucket(db: sqlite3.Connection, owner: str, period: sqlite3.Row, now: int) -> UsageBucket:
        operations = tuple(
            Operation(row["id"], Outcome.PENDING if row["state"] in ("reserved", "dispatched")
                      else Outcome(row["state"]), bool(row["credited"]))
            for row in db.execute(
                "SELECT * FROM operations WHERE owner=? AND period=? AND state != 'issued'",
                (owner, period["period"]),
            )
        )
        revision = db.execute("SELECT revision FROM owners WHERE owner=?", (owner,)).fetchone()[0]
        return UsageBucket(owner, AllowancePeriod(
            period["period"], Plan(period["plan"]), period["start"], period["end"],
        ), now, revision, operations)

    def activate(self, owner: str, period: AllowancePeriod, *, verified_until: int) -> None:
        """Trusted-service grant/refresh; NEVER an ownership or Apple verifier.

        Conflicting periods, shortening and grace extensions require a future
        reconciler. Revoked periods cannot be resurrected by replay.
        """
        if (type(owner) is not str or len(owner) != 64
                or any(c not in "0123456789abcdef" for c in owner)):
            raise UsageError("invalid_owner")
        with self._transaction() as (db, now):
            if (type(verified_until) is not int
                    or not period.start <= now < verified_until <= period.end):
                raise UsageError("invalid_verification_boundary")
            if db.execute("SELECT 1 FROM owners WHERE owner=?", (owner,)).fetchone() is None:
                if db.execute("SELECT count(*) FROM owners").fetchone()[0] >= MAX_OWNERS:
                    raise CommerceStoreError("owner_capacity")
                db.execute("INSERT INTO owners VALUES (?, NULL, ?, 0)", (owner, now))
            owner_row = self._owner(db, owner, now)
            if owner_row["active_period"] is not None:
                active = self._period(db, owner, owner_row["active_period"])
                if (period.plan is Plan.FREE and active["plan"] == "plus"
                        and not active["revoked"] and now < active["end"]):
                    raise UsageError("paid_period_unresolved")
            prior = db.execute(
                "SELECT * FROM periods WHERE owner=? AND period=?", (owner, period.period_id),
            ).fetchone()
            if prior is not None:
                if (prior["revoked"] or (prior["plan"], prior["start"], prior["end"]) != (
                        period.plan, period.start, period.end)
                        or verified_until < prior["verified_until"]):
                    raise UsageError("period_conflict")
                changed = (owner_row["active_period"] != period.period_id
                           or prior["verified_until"] != verified_until)
                db.execute("UPDATE periods SET verified_until=? WHERE owner=? AND period=?",
                           (verified_until, owner, period.period_id))
            else:
                # Canonical free boundaries and paid overlap exclusion prevent
                # aliases/restores from manufacturing an additional allowance.
                if db.execute(
                    "SELECT 1 FROM periods WHERE owner=? AND plan=? AND start < ? AND end > ?",
                    (owner, period.plan, period.end, period.start),
                ).fetchone():
                    raise UsageError("period_conflict")
                if db.execute("SELECT count(*) FROM periods WHERE owner=?", (owner,)
                              ).fetchone()[0] >= MAX_PERIODS_PER_OWNER:
                    raise CommerceStoreError("period_capacity")
                db.execute("INSERT INTO periods VALUES (?, ?, ?, ?, ?, ?, 0)",
                           (owner, period.period_id, period.plan, period.start, period.end,
                            verified_until))
                changed = True
            db.execute("UPDATE owners SET active_period=? WHERE owner=?", (period.period_id, owner))
            if changed:
                self._bump(db, owner)

    def revoke(self, owner: str, period_id: str) -> None:
        """Trusted, verified revocation; retain pending work and all usage."""
        with self._transaction() as (db, now):
            self._owner(db, owner, now)
            period = self._period(db, owner, period_id)
            if not period["revoked"]:
                db.execute("UPDATE periods SET revoked=1 WHERE owner=? AND period=?",
                           (owner, period_id))
                self._bump(db, owner)

    def usage(self, owner: str) -> UsageBucket:
        with self._transaction() as (db, now):
            row = self._owner(db, owner, now)
            return self._bucket(db, owner, self._period(db, owner, row["active_period"]), now)

    @staticmethod
    def _operation(db: sqlite3.Connection, owner: str, operation: str) -> sqlite3.Row:
        row: sqlite3.Row | None = db.execute(
            "SELECT * FROM operations WHERE owner=? AND id=?", (owner, operation),
        ).fetchone()
        if row is None:
            raise UsageError("operation_not_found")
        return row

    @staticmethod
    def _result(row: sqlite3.Row) -> StoredOperation:
        return StoredOperation(row["id"], row["period"], row["state"], bool(row["credited"]))

    def operation(self, owner: str, operation: str) -> StoredOperation:
        with self._transaction() as (db, now):
            self._owner(db, owner, now)
            return self._result(self._operation(db, owner, operation))

    def issue(self, owner: str) -> StoredOperation:
        with self._transaction() as (db, now):
            row = self._owner(db, owner, now)
            period = self._period(db, owner, row["active_period"])
            self._usable(row, period, now)
            if db.execute("SELECT count(*) FROM operations WHERE owner=? AND period=?",
                          (owner, period["period"])).fetchone()[0] >= MAX_OPERATIONS_PER_PERIOD:
                raise CommerceStoreError("operation_capacity")
            operation = secrets.token_urlsafe(32)
            db.execute("INSERT INTO operations VALUES (?, ?, ?, ?, 'issued', 0)",
                       (operation, owner, period["period"], min(now + HANDLE_TTL, period["end"])))
            self._bump(db, owner)
            return self._result(self._operation(db, owner, operation))

    def reserve(self, owner: str, operation: str) -> StoredOperation:
        with self._transaction() as (db, now):
            row = self._owner(db, owner, now)
            op = self._operation(db, owner, operation)
            if op["state"] != "issued":
                return self._result(op)
            period = self._period(db, owner, op["period"])
            self._usable(row, period, now)
            if now >= op["expires_at"]:
                raise UsageError("operation_expired")
            if db.execute("SELECT 1 FROM operations WHERE owner=? "
                          "AND state IN ('reserved', 'dispatched')", (owner,)).fetchone():
                raise UsageError("operation_pending")
            self._bucket(db, owner, period, now).reserve(
                owner_key=owner, operation_id=operation, now=now, entitlement_active=True,
            )
            db.execute("UPDATE operations SET state='reserved' WHERE id=?", (operation,))
            self._bump(db, owner)
            return self._result(self._operation(db, owner, operation))

    def fence_dispatch(self, owner: str, operation: str) -> bool:
        """Exactly one caller wins; a crash consumes the fence permanently.

        True is NOT global admission. The future coordinator must also reserve
        provider liability and handle every cross-store crash boundary.
        """
        with self._transaction() as (db, now):
            row = self._owner(db, owner, now)
            op = self._operation(db, owner, operation)
            if op["state"] != "reserved":
                return False
            self._usable(row, self._period(db, owner, op["period"]), now)
            db.execute("UPDATE operations SET state='dispatched' WHERE id=?", (operation,))
            self._bump(db, owner)
            return True

    def settle(self, owner: str, operation: str, outcome: Outcome) -> StoredOperation:
        """Trusted durable outcome/quiescence only; timeout is not a failure."""
        if not isinstance(outcome, Outcome) or outcome is Outcome.PENDING:
            raise UsageError("invalid_outcome")
        with self._transaction() as (db, now):
            self._owner(db, owner, now)
            op = self._operation(db, owner, operation)
            if op["state"] == outcome:
                return self._result(op)
            if (op["state"] not in ("reserved", "dispatched")
                    or (outcome is Outcome.SUCCEEDED and op["state"] != "dispatched")):
                raise UsageError("outcome_conflict")
            self._bucket(db, owner, self._period(db, owner, op["period"]), now).settle(
                owner_key=owner, operation_id=operation, outcome=outcome, now=now,
            )
            db.execute("UPDATE operations SET state=? WHERE id=?", (outcome, operation))
            self._bump(db, owner)
            return self._result(self._operation(db, owner, operation))

    def credit_delivery(self, owner: str, operation: str) -> StoredOperation:
        with self._transaction() as (db, now):
            row = self._owner(db, owner, now)
            op = self._operation(db, owner, operation)
            if op["credited"]:
                return self._result(op)
            period = self._period(db, owner, op["period"])
            self._usable(row, period, now)
            self._bucket(db, owner, period, now).credit_delivery(
                owner_key=owner, operation_id=operation, now=now, entitlement_active=True,
            )
            db.execute("UPDATE operations SET credited=1 WHERE id=?", (operation,))
            self._bump(db, owner)
            return self._result(self._operation(db, owner, operation))
