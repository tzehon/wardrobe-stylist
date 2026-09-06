"""A global, durable UTC-month admission ceiling for the pinned Haiku model.

One unit is one uncached Haiku input token (USD 0.000001); an output token costs
five units. Reserve the complete worst-case charge before contacting Anthropic.
Only a terminal success with checked usage may refund the unused reservation.
This database contains aggregate counters and random reservation metadata only.
It never receives installation identifiers, catalogs, prompts, or responses.

Provisioning is explicit. Runtime never creates or resets a missing database,
changes its approved limits, expires a reservation, or refunds uncertain work.
The production database must share a durable, single-writer SQLite volume across
all application processes; separate replicas must not have independent copies.
"""

from __future__ import annotations

import os
import secrets
import sqlite3
import stat
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import UTC, datetime
from pathlib import Path

INPUT_UNIT_PRICE = 1
OUTPUT_UNIT_PRICE = 5
MAX_INPUT_TOKEN_BOUND = 200_000
MAX_OUTPUT_TOKEN_BOUND = 2_048
MAX_MONTHLY_UNITS = 100_000_000
MAX_MONTHLY_REQUESTS = 100_000
MAX_CONCURRENCY = 4
_APPLICATION_ID = 0x57424149
_SCHEMA_VERSION = 1

_SCHEMA = """
CREATE TABLE budget_state (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    month INTEGER NOT NULL CHECK (month >= 200001),
    charged_units INTEGER NOT NULL CHECK (charged_units >= 0),
    admitted_requests INTEGER NOT NULL CHECK (admitted_requests >= 0),
    unit_limit INTEGER NOT NULL CHECK (unit_limit > 0),
    request_limit INTEGER NOT NULL CHECK (request_limit > 0),
    concurrency_limit INTEGER NOT NULL CHECK (concurrency_limit > 0),
    halted INTEGER NOT NULL CHECK (halted IN (0, 1))
);
CREATE TABLE pending_reservations (
    reservation_id TEXT PRIMARY KEY CHECK (length(reservation_id) = 64),
    month INTEGER NOT NULL,
    input_bound INTEGER NOT NULL CHECK (input_bound > 0),
    output_bound INTEGER NOT NULL CHECK (output_bound > 0),
    charged_units INTEGER NOT NULL CHECK (charged_units > 0),
    uncertain INTEGER NOT NULL DEFAULT 0 CHECK (uncertain IN (0, 1))
);
"""
_EXPECTED_SCHEMA = frozenset(" ".join(part.split()) for part in _SCHEMA.split(";") if part.strip())


class BudgetUnavailable(RuntimeError):
    """Storage, policy, or accounting cannot establish safe admission."""


class BudgetExceeded(RuntimeError):
    """The approved monthly allowance or global concurrency is exhausted."""


@dataclass(frozen=True)
class Reservation:
    reservation_id: str = field(repr=False)


@dataclass(frozen=True)
class BudgetSnapshot:
    month: int
    charged_units: int = field(repr=False)
    admitted_requests: int = field(repr=False)
    unit_limit: int = field(repr=False)
    request_limit: int = field(repr=False)
    active_reservations: int
    uncertain_reservations: int
    max_concurrency: int
    halted: bool

    @property
    def alert_required(self) -> bool:
        """An 80% envelope threshold, uncertainty, or a halt needs owner action."""
        return (
            self.halted
            or self.uncertain_reservations > 0
            or self.charged_units * 5 >= self.unit_limit * 4
            or self.admitted_requests * 5 >= self.request_limit * 4
        )


def _validate_integer(value: int, maximum: int) -> None:
    if type(value) is not int or not 1 <= value <= maximum:
        raise BudgetUnavailable("styling_budget_invalid_limit")


def _validate_policy(units: int, requests: int, concurrency: int) -> None:
    _validate_integer(units, MAX_MONTHLY_UNITS)
    _validate_integer(requests, MAX_MONTHLY_REQUESTS)
    _validate_integer(concurrency, MAX_CONCURRENCY)


def _month(clock: Callable[[], datetime]) -> int:
    now = clock()
    if now.tzinfo is None or now.utcoffset() is None:
        raise BudgetUnavailable("styling_budget_clock_invalid")
    now = now.astimezone(UTC)
    result = now.year * 100 + now.month
    if result < 200001:
        raise BudgetUnavailable("styling_budget_clock_invalid")
    return result


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _validate_parent(path: Path) -> None:
    metadata = path.parent.lstat()
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or stat.S_IMODE(metadata.st_mode) != 0o700
        or metadata.st_uid != os.geteuid()
    ):
        raise BudgetUnavailable("styling_budget_directory_not_private")


def _validate_file(metadata: os.stat_result) -> None:
    if (
        not stat.S_ISREG(metadata.st_mode)
        or stat.S_IMODE(metadata.st_mode) != 0o600
        or metadata.st_uid != os.geteuid()
        or metadata.st_nlink != 1
    ):
        raise BudgetUnavailable("styling_budget_file_not_private")


@contextmanager
def _connection(path: Path, *, read_only: bool = False) -> Iterator[sqlite3.Connection]:
    """Require the already-provisioned private file; never recreate on failure."""
    descriptor: int | None = None
    connection: sqlite3.Connection | None = None
    try:
        _validate_parent(path)
        _validate_file(path.lstat())
        flags = os.O_RDONLY if read_only else os.O_RDWR
        flags |= getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
        descriptor = os.open(path, flags)
        opened = os.fstat(descriptor)
        _validate_file(opened)
        mode = "ro" if read_only else "rw"
        connection = sqlite3.connect(path.as_uri() + f"?mode={mode}", uri=True, timeout=5.0)
        current = path.lstat()
        _validate_file(current)
        if (opened.st_dev, opened.st_ino) != (current.st_dev, current.st_ino):
            raise BudgetUnavailable("styling_budget_file_changed")
        connection.row_factory = sqlite3.Row
        if read_only:
            connection.execute("PRAGMA query_only = ON")
        else:
            connection.execute("PRAGMA synchronous = FULL")
        connection.execute("PRAGMA busy_timeout = 5000")
        if connection.execute("PRAGMA synchronous").fetchone()[0] != 2:
            raise BudgetUnavailable("styling_budget_durability_invalid")
        if connection.execute("PRAGMA journal_mode").fetchone()[0] != "wal":
            raise BudgetUnavailable("styling_budget_durability_invalid")
        if (
            connection.execute("PRAGMA application_id").fetchone()[0] != _APPLICATION_ID
            or connection.execute("PRAGMA user_version").fetchone()[0] != _SCHEMA_VERSION
        ):
            raise BudgetUnavailable("styling_budget_schema_invalid")
        actual_schema = frozenset(
            " ".join(row[0].split())
            for row in connection.execute("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL")
        )
        if actual_schema != _EXPECTED_SCHEMA:
            raise BudgetUnavailable("styling_budget_schema_invalid")
        yield connection
    except (OSError, sqlite3.Error, ValueError) as exc:
        raise BudgetUnavailable("styling_budget_storage_unavailable") from exc
    finally:
        if connection is not None:
            connection.close()
        if descriptor is not None:
            os.close(descriptor)


def initialize_budget_database(
    path: Path,
    *,
    monthly_unit_limit: int,
    monthly_request_limit: int,
    max_concurrency: int,
    clock: Callable[[], datetime] = _utc_now,
) -> None:
    """Owner-only first provisioning; an existing file is never modified.

    Keep AI disabled while provisioning. A lost/restored database requires an
    independently reconciled conservative ledger, never this initializer during
    the same month. Exact private approved limits belong in runtime secrets.
    """
    _validate_policy(monthly_unit_limit, monthly_request_limit, max_concurrency)
    month = _month(clock)
    path = path.absolute()
    try:
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        _validate_parent(path)
        flags = os.O_RDWR | os.O_CREAT | os.O_EXCL
        flags |= getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_CLOEXEC", 0)
        descriptor = os.open(path, flags, 0o600)
        os.close(descriptor)
        # A provisioning interruption leaves an invalid file; runtime fails
        # closed and initialization refuses to overwrite it.
        with sqlite3.connect(path) as connection:
            connection.execute("PRAGMA journal_mode = WAL")
            connection.execute("PRAGMA synchronous = FULL")
            connection.executescript(_SCHEMA)
            connection.execute(f"PRAGMA application_id = {_APPLICATION_ID}")
            connection.execute(f"PRAGMA user_version = {_SCHEMA_VERSION}")
            connection.execute(
                "INSERT INTO budget_state VALUES (1, ?, 0, 0, ?, ?, ?, 0)",
                (month, monthly_unit_limit, monthly_request_limit, max_concurrency),
            )
        directory = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    except (OSError, sqlite3.Error) as exc:
        raise BudgetUnavailable("styling_budget_provisioning_failed") from exc


def _load_state(
    connection: sqlite3.Connection, units: int, requests: int, concurrency: int
) -> sqlite3.Row:
    state: sqlite3.Row | None = connection.execute(
        "SELECT * FROM budget_state WHERE singleton = 1"
    ).fetchone()
    if state is None or (
        state["unit_limit"], state["request_limit"], state["concurrency_limit"]
    ) != (units, requests, concurrency):
        raise BudgetUnavailable("styling_budget_policy_mismatch")
    pending = connection.execute(
        "SELECT COUNT(*), COALESCE(SUM(charged_units), 0), COALESCE(MAX(month), 0) "
        "FROM pending_reservations"
    ).fetchone()
    if (
        pending[0] > concurrency
        or pending[0] > state["admitted_requests"]
        or pending[1] > state["charged_units"]
        or pending[2] > state["month"]
        or state["charged_units"] > units
        or state["admitted_requests"] > requests
    ):
        raise BudgetUnavailable("styling_budget_accounting_invalid")
    return state


def inspect_budget_database(
    path: Path,
    *,
    monthly_unit_limit: int,
    monthly_request_limit: int,
    max_concurrency: int,
) -> BudgetSnapshot:
    """Inspect consistent persisted state with SQLite mode=ro and query_only.

    Does not create schema, roll months, reconcile reservations, or write WAL
    frames. Current WAL contents remain visible (immutable mode would hide them).
    The caller must apply current-month and deployment policy checks separately.
    """
    _validate_policy(monthly_unit_limit, monthly_request_limit, max_concurrency)
    with _connection(path.absolute(), read_only=True) as connection, connection:
        connection.execute("BEGIN")
        if [row[0] for row in connection.execute("PRAGMA quick_check")] != ["ok"]:
            raise BudgetUnavailable("styling_budget_integrity_invalid")
        state = _load_state(
            connection, monthly_unit_limit, monthly_request_limit, max_concurrency
        )
        pending = connection.execute(
            "SELECT COUNT(*), COALESCE(SUM(uncertain), 0) FROM pending_reservations"
        ).fetchone()
        return BudgetSnapshot(
            month=state["month"],
            charged_units=state["charged_units"],
            admitted_requests=state["admitted_requests"],
            unit_limit=state["unit_limit"],
            request_limit=state["request_limit"],
            active_reservations=pending[0],
            uncertain_reservations=pending[1],
            max_concurrency=state["concurrency_limit"],
            halted=bool(state["halted"]),
        )


class StylingBudget:
    def __init__(
        self,
        path: Path,
        *,
        monthly_unit_limit: int,
        monthly_request_limit: int,
        max_concurrency: int,
        clock: Callable[[], datetime] = _utc_now,
    ) -> None:
        _validate_policy(monthly_unit_limit, monthly_request_limit, max_concurrency)
        self.path = path.absolute()
        self.monthly_unit_limit = monthly_unit_limit
        self.monthly_request_limit = monthly_request_limit
        self.max_concurrency = max_concurrency
        self.clock = clock
        # Construction verifies provisioned storage without a write or reset.
        self.snapshot()

    def _state(self, connection: sqlite3.Connection) -> sqlite3.Row:
        return _load_state(
            connection, self.monthly_unit_limit, self.monthly_request_limit, self.max_concurrency
        )

    def _roll_period(self, connection: sqlite3.Connection, state: sqlite3.Row) -> sqlite3.Row:
        month = _month(self.clock)
        if month < state["month"]:
            raise BudgetUnavailable("styling_budget_clock_regressed")
        if month > state["month"]:
            pending = connection.execute(
                "SELECT COUNT(*), COALESCE(SUM(charged_units), 0) FROM pending_reservations"
            ).fetchone()
            # In-flight work may bill after midnight. Conservatively carry its
            # full charge/admission before any reservation can be removed.
            connection.execute(
                "UPDATE budget_state SET month = ?, charged_units = ?, admitted_requests = ? "
                "WHERE singleton = 1",
                (month, pending[1], pending[0]),
            )
            state = self._state(connection)
        return state

    def reserve(self, input_token_bound: int, output_token_bound: int) -> Reservation:
        _validate_integer(input_token_bound, MAX_INPUT_TOKEN_BOUND)
        _validate_integer(output_token_bound, MAX_OUTPUT_TOKEN_BOUND)
        units = input_token_bound * INPUT_UNIT_PRICE + output_token_bound * OUTPUT_UNIT_PRICE
        reservation = Reservation(secrets.token_hex(32))
        with _connection(self.path) as connection, connection:
            connection.execute("BEGIN IMMEDIATE")
            state = self._roll_period(connection, self._state(connection))
            month = state["month"]
            if state["halted"]:
                raise BudgetUnavailable("styling_budget_halted")
            pending = connection.execute(
                "SELECT COUNT(*) FROM pending_reservations"
            ).fetchone()
            charged, admitted = state["charged_units"], state["admitted_requests"]
            if pending[0] >= self.max_concurrency:
                raise BudgetExceeded("styling_budget_concurrency_exhausted")
            if (
                charged + units > self.monthly_unit_limit
                or admitted + 1 > self.monthly_request_limit
            ):
                raise BudgetExceeded("styling_budget_month_exhausted")
            connection.execute(
                "UPDATE budget_state SET month = ?, charged_units = ?, admitted_requests = ? "
                "WHERE singleton = 1",
                (month, charged + units, admitted + 1),
            )
            connection.execute(
                "INSERT INTO pending_reservations VALUES (?, ?, ?, ?, ?, 0)",
                (reservation.reservation_id, month, input_token_bound, output_token_bound, units),
            )
        return reservation

    def complete(self, reservation: Reservation, *, input_tokens: int, output_tokens: int) -> None:
        """Settle one successful response once, using validated uncached usage.

        Invalid or unexpectedly large usage halts admission across month changes
        and leaves the reservation charged. No caller-supplied reservation bounds
        are trusted. A duplicate settlement can never create a second refund.
        """
        invalid = False
        with _connection(self.path) as connection, connection:
            connection.execute("BEGIN IMMEDIATE")
            state = self._roll_period(connection, self._state(connection))
            pending = self._pending(connection, reservation)
            invalid = (
                type(input_tokens) is not int
                or type(output_tokens) is not int
                or input_tokens < 0
                or output_tokens < 0
                or input_tokens > pending["input_bound"]
                or output_tokens > pending["output_bound"]
            )
            if invalid:
                connection.execute("UPDATE budget_state SET halted = 1 WHERE singleton = 1")
                connection.execute(
                    "UPDATE pending_reservations SET uncertain = 1 WHERE reservation_id = ?",
                    (reservation.reservation_id,),
                )
            else:
                actual = input_tokens * INPUT_UNIT_PRICE + output_tokens * OUTPUT_UNIT_PRICE
                if pending["month"] == state["month"]:
                    refund = pending["charged_units"] - actual
                    if state["charged_units"] < refund:
                        raise BudgetUnavailable("styling_budget_accounting_invalid")
                    connection.execute(
                        "UPDATE budget_state SET charged_units = charged_units - ? "
                        "WHERE singleton = 1",
                        (refund,),
                    )
                # Previous-month carry is never refunded into the new month.
                connection.execute(
                    "DELETE FROM pending_reservations WHERE reservation_id = ?",
                    (reservation.reservation_id,),
                )
        if invalid:
            raise BudgetUnavailable("styling_budget_usage_invalid")

    @staticmethod
    def _pending(connection: sqlite3.Connection, reservation: Reservation) -> sqlite3.Row:
        pending: sqlite3.Row | None = connection.execute(
            "SELECT * FROM pending_reservations WHERE reservation_id = ?",
            (reservation.reservation_id,),
        ).fetchone()
        if pending is None:
            raise BudgetUnavailable("styling_budget_reservation_unknown")
        return pending

    def finish_failed(self, reservation: Reservation) -> None:
        """A known terminal provider response releases its slot, never its charge."""
        with _connection(self.path) as connection, connection:
            connection.execute("BEGIN IMMEDIATE")
            self._roll_period(connection, self._state(connection))
            self._pending(connection, reservation)
            connection.execute(
                "DELETE FROM pending_reservations WHERE reservation_id = ?",
                (reservation.reservation_id,),
            )

    def fail(self, reservation: Reservation) -> None:
        """An uncertain timeout/cancellation retains its full charge and slot."""
        with _connection(self.path) as connection, connection:
            connection.execute("BEGIN IMMEDIATE")
            self._roll_period(connection, self._state(connection))
            self._pending(connection, reservation)
            connection.execute(
                "UPDATE pending_reservations SET uncertain = 1 WHERE reservation_id = ?",
                (reservation.reservation_id,),
            )

    def recover_pending(
        self, *, ai_styling_disabled: bool, provider_quiescence_confirmed: bool
    ) -> int:
        """Explicit offline owner recovery; never refund or clear a safety halt.

        The caller must independently verify the deployed switch is disabled,
        every worker has drained/stopped, and the provider has no ongoing work.
        An elapsed lease/timeout is not that proof. This API is never on a route.
        """
        if ai_styling_disabled is not True or provider_quiescence_confirmed is not True:
            raise BudgetUnavailable("styling_budget_recovery_not_authorized")
        with _connection(self.path) as connection, connection:
            connection.execute("BEGIN IMMEDIATE")
            self._roll_period(connection, self._state(connection))
            count = connection.execute("SELECT COUNT(*) FROM pending_reservations").fetchone()[0]
            connection.execute("DELETE FROM pending_reservations")
        return int(count)

    def snapshot(self) -> BudgetSnapshot:
        """Read aggregate health without disclosing IDs or mutating the ledger."""
        return inspect_budget_database(
            self.path,
            monthly_unit_limit=self.monthly_unit_limit,
            monthly_request_limit=self.monthly_request_limit,
            max_concurrency=self.max_concurrency,
        )
