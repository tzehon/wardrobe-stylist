"""Durable global admission, reservation accounting, and fail-closed recovery."""

import os
import sqlite3
import stat
from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor
from datetime import UTC, datetime, timedelta, timezone
from multiprocessing import get_context
from pathlib import Path

import pytest

from app.styling_budget import (
    BUDGET_MODEL,
    BUDGET_PRICING_POLICY,
    BUDGET_UNIT,
    INPUT_UNIT_PRICE,
    MAX_INPUT_TOKEN_BOUND,
    MAX_OUTPUT_TOKEN_BOUND,
    OUTPUT_UNIT_PRICE,
    BudgetExceeded,
    BudgetUnavailable,
    Reservation,
    StylingBudget,
    initialize_budget_database,
    inspect_budget_database,
)

SEPTEMBER = datetime(2026, 9, 6, 0, 0, tzinfo=UTC)
OCTOBER = datetime(2026, 10, 1, 0, 0, tzinfo=UTC)


class Clock:
    def __init__(self) -> None:
        self.now = SEPTEMBER

    def __call__(self) -> datetime:
        return self.now


def make_budget(
    tmp_path: Path,
    *,
    units: int = 1_000,
    requests: int = 20,
    concurrency: int = 4,
    clock: Clock | None = None,
) -> StylingBudget:
    selected_clock = clock or Clock()
    path = tmp_path / "private-budget" / "budget.sqlite3"
    initialize_budget_database(
        path,
        monthly_unit_limit=units,
        monthly_request_limit=requests,
        max_concurrency=concurrency,
        clock=selected_clock,
    )
    return StylingBudget(
        path,
        monthly_unit_limit=units,
        monthly_request_limit=requests,
        max_concurrency=concurrency,
        clock=selected_clock,
    )


def reopen(budget: StylingBudget) -> StylingBudget:
    return StylingBudget(
        budget.path,
        monthly_unit_limit=budget.monthly_unit_limit,
        monthly_request_limit=budget.monthly_request_limit,
        max_concurrency=budget.max_concurrency,
        clock=budget.clock,
    )


def test_private_provisioning_never_overwrites_existing_month(tmp_path):
    budget = make_budget(tmp_path)
    budget.reserve(50, 10)
    assert stat.S_IMODE(os.stat(budget.path.parent).st_mode) == 0o700
    assert stat.S_IMODE(os.stat(budget.path).st_mode) == 0o600
    with pytest.raises(BudgetUnavailable, match="provisioning_failed"):
        initialize_budget_database(
            budget.path,
            monthly_unit_limit=1_000,
            monthly_request_limit=20,
            max_concurrency=4,
        )
    assert reopen(budget).snapshot().charged_units == 200


def test_missing_database_fails_closed_without_creating_file(tmp_path):
    path = tmp_path / "missing.sqlite3"
    with pytest.raises(BudgetUnavailable, match="storage_unavailable"):
        StylingBudget(
            path,
            monthly_unit_limit=1_000,
            monthly_request_limit=20,
            max_concurrency=4,
        )
    assert not path.exists()


def test_lost_database_is_not_recreated_by_existing_instance(tmp_path):
    budget = make_budget(tmp_path)
    budget.reserve(50, 10)
    budget.path.unlink()
    with pytest.raises(BudgetUnavailable, match="storage_unavailable"):
        budget.reserve(50, 10)
    assert not budget.path.exists()


@pytest.mark.parametrize("limit", [0, -1, True, 1.5, 1_000_000_001])
def test_invalid_or_unapproved_limit_fails_closed(tmp_path, limit):
    with pytest.raises(BudgetUnavailable, match="invalid_limit"):
        StylingBudget(
            tmp_path / "budget.sqlite3",
            monthly_unit_limit=limit,
            monthly_request_limit=20,
            max_concurrency=4,
        )


@pytest.mark.parametrize("units, requests, concurrency", [(1001, 20, 4), (999, 20, 4),
                                                       (1000, 21, 4), (1000, 20, 3)])
def test_runtime_cannot_change_approved_policy(tmp_path, units, requests, concurrency):
    budget = make_budget(tmp_path)
    with pytest.raises(BudgetUnavailable, match="policy_mismatch"):
        StylingBudget(
            budget.path,
            monthly_unit_limit=units,
            monthly_request_limit=requests,
            max_concurrency=concurrency,
        )


def test_reservation_charges_worst_case_before_provider_work(tmp_path):
    budget = make_budget(tmp_path)
    reservation = budget.reserve(100, 20)
    state = reopen(budget).snapshot()
    assert state.charged_units == 400
    assert state.admitted_requests == 1
    assert state.active_reservations == 1
    budget.complete(reservation, input_tokens=40, output_tokens=10)
    state = reopen(budget).snapshot()
    assert state.charged_units == 180
    assert state.admitted_requests == 1
    assert state.active_reservations == 0


def test_completed_reservation_cannot_refund_twice(tmp_path):
    budget = make_budget(tmp_path)
    reservation = budget.reserve(100, 20)
    budget.complete(reservation, input_tokens=40, output_tokens=10)
    with pytest.raises(BudgetUnavailable, match="reservation_unknown"):
        budget.complete(reservation, input_tokens=0, output_tokens=0)
    assert budget.snapshot().charged_units == 180


def test_unrecognized_reservation_cannot_change_accounting(tmp_path):
    budget = make_budget(tmp_path)
    budget.reserve(100, 20)
    with pytest.raises(BudgetUnavailable, match="reservation_unknown"):
        budget.complete(Reservation("f" * 64), input_tokens=0, output_tokens=0)
    assert budget.snapshot().charged_units == 400


def test_failed_terminal_response_keeps_charge_and_admission_but_frees_slot(tmp_path):
    budget = make_budget(tmp_path, units=800, requests=2, concurrency=1)
    reservation = budget.reserve(100, 20)
    budget.finish_failed(reservation)
    budget.reserve(100, 20)
    state = budget.snapshot()
    assert (state.charged_units, state.admitted_requests, state.active_reservations) == (800, 2, 1)


def test_uncertain_failure_keeps_charge_and_concurrency_across_restart(tmp_path):
    budget = make_budget(tmp_path, concurrency=1)
    reservation = budget.reserve(100, 20)
    budget.fail(reservation)
    second = reopen(budget)
    with pytest.raises(BudgetExceeded, match="concurrency_exhausted"):
        second.reserve(1, 1)
    state = second.snapshot()
    assert state.charged_units == 400
    assert state.admitted_requests == 1
    assert state.active_reservations == 1
    assert state.uncertain_reservations == 1
    assert state.alert_required


def test_crash_leaves_pending_reservation_without_requiring_failure_handler(tmp_path):
    budget = make_budget(tmp_path, concurrency=1)
    budget.reserve(100, 20)
    with pytest.raises(BudgetExceeded, match="concurrency_exhausted"):
        reopen(budget).reserve(1, 1)
    assert budget.snapshot().charged_units == 400


def test_monthly_tokens_block_even_with_requests_and_concurrency_available(tmp_path):
    budget = make_budget(tmp_path, units=599)
    first = budget.reserve(100, 20)
    budget.finish_failed(first)
    with pytest.raises(BudgetExceeded, match="month_exhausted"):
        budget.reserve(50, 10)
    assert budget.snapshot().charged_units == 400
    assert budget.snapshot().admitted_requests == 1


def test_monthly_admissions_are_not_refunded_by_zero_usage(tmp_path):
    budget = make_budget(tmp_path, requests=1)
    first = budget.reserve(100, 20)
    budget.complete(first, input_tokens=0, output_tokens=0)
    with pytest.raises(BudgetExceeded, match="month_exhausted"):
        budget.reserve(1, 1)
    assert budget.snapshot().charged_units == 0
    assert budget.snapshot().admitted_requests == 1


@pytest.mark.parametrize("input_tokens, output_tokens", [(101, 10), (40, 21), (-1, 0),
                                                      (1.5, 0), (True, 0), (40, -1)])
def test_invalid_usage_never_refunds_and_halts_future_months(tmp_path, input_tokens, output_tokens):
    clock = Clock()
    budget = make_budget(tmp_path, clock=clock)
    reservation = budget.reserve(100, 20)
    with pytest.raises(BudgetUnavailable, match="usage_invalid"):
        budget.complete(reservation, input_tokens=input_tokens, output_tokens=output_tokens)
    state = reopen(budget).snapshot()
    assert state.charged_units == 400
    assert state.halted
    assert state.uncertain_reservations == 1
    clock.now = OCTOBER
    with pytest.raises(BudgetUnavailable, match="halted"):
        budget.reserve(1, 1)


def test_completed_previous_month_is_reset_only_after_utc_month_boundary(tmp_path):
    clock = Clock()
    clock.now = datetime(2026, 9, 30, 23, 59, 59, tzinfo=UTC)
    budget = make_budget(tmp_path, requests=1, clock=clock)
    first = budget.reserve(100, 20)
    budget.finish_failed(first)
    with pytest.raises(BudgetExceeded):
        budget.reserve(1, 1)
    clock.now = OCTOBER
    budget.reserve(50, 10)
    state = budget.snapshot()
    assert state.month == 202610
    assert state.admitted_requests == 1
    assert state.charged_units == 200


def test_local_timezone_does_not_reset_before_utc_boundary(tmp_path):
    clock = Clock()
    budget = make_budget(tmp_path, requests=1, clock=clock)
    budget.finish_failed(budget.reserve(100, 20))
    clock.now = datetime(2026, 10, 1, 7, 59, 59, tzinfo=timezone(timedelta(hours=8)))
    with pytest.raises(BudgetExceeded, match="month_exhausted"):
        budget.reserve(1, 1)
    clock.now += timedelta(seconds=1)
    budget.reserve(1, 1)
    assert budget.snapshot().month == 202610


def test_clock_regression_cannot_open_another_monthly_allowance(tmp_path):
    clock = Clock()
    budget = make_budget(tmp_path, clock=clock)
    clock.now = OCTOBER
    budget.reserve(100, 20)
    clock.now = SEPTEMBER
    with pytest.raises(BudgetUnavailable, match="clock_regressed"):
        budget.reserve(1, 1)
    assert budget.snapshot().charged_units == 400


def test_timezone_naive_clock_fails_before_provisioning(tmp_path):
    clock = Clock()
    clock.now = datetime(2026, 9, 6)
    with pytest.raises(BudgetUnavailable, match="clock_invalid"):
        make_budget(tmp_path, clock=clock)
    assert not (tmp_path / "private-budget" / "budget.sqlite3").exists()


def test_previous_month_pending_charge_and_admission_carry_into_next_month(tmp_path):
    clock = Clock()
    budget = make_budget(tmp_path, clock=clock)
    earlier = budget.reserve(100, 20)
    clock.now = OCTOBER
    budget.reserve(50, 10)
    assert budget.snapshot().charged_units == 600
    assert budget.snapshot().admitted_requests == 2
    # A late successful response never refunds previous-month carry.
    budget.complete(earlier, input_tokens=0, output_tokens=0)
    assert budget.snapshot().charged_units == 600
    assert budget.snapshot().active_reservations == 1


@pytest.mark.parametrize("finish", ["complete", "finish_failed", "recover_pending"])
def test_settlement_after_midnight_carries_charge_before_removing_slot(tmp_path, finish):
    clock = Clock()
    budget = make_budget(tmp_path, clock=clock)
    earlier = budget.reserve(100, 20)
    clock.now = OCTOBER
    if finish == "complete":
        budget.complete(earlier, input_tokens=0, output_tokens=0)
    elif finish == "finish_failed":
        budget.finish_failed(earlier)
    else:
        budget.recover_pending(ai_styling_disabled=True, provider_quiescence_confirmed=True)
    assert budget.snapshot().month == 202610
    assert budget.snapshot().charged_units == 400
    assert budget.snapshot().admitted_requests == 1
    assert budget.snapshot().active_reservations == 0


def test_uncertain_slots_do_not_expire_even_after_multiple_months(tmp_path):
    clock = Clock()
    budget = make_budget(tmp_path, concurrency=1, clock=clock)
    budget.fail(budget.reserve(100, 20))
    clock.now = datetime(2027, 2, 1, tzinfo=UTC)
    with pytest.raises(BudgetExceeded, match="concurrency_exhausted"):
        reopen(budget).reserve(1, 1)
    assert budget.snapshot().active_reservations == 1


@pytest.mark.parametrize("disabled, quiescent", [(False, True), (True, False), (False, False)])
def test_recovery_requires_both_explicit_preconditions(tmp_path, disabled, quiescent):
    budget = make_budget(tmp_path)
    budget.fail(budget.reserve(100, 20))
    with pytest.raises(BudgetUnavailable, match="recovery_not_authorized"):
        budget.recover_pending(
            ai_styling_disabled=disabled, provider_quiescence_confirmed=quiescent
        )
    assert budget.snapshot().active_reservations == 1


def test_explicit_quiescent_recovery_preserves_all_charges_and_halts(tmp_path):
    budget = make_budget(tmp_path)
    reservation = budget.reserve(100, 20)
    with pytest.raises(BudgetUnavailable):
        budget.complete(reservation, input_tokens=101, output_tokens=0)
    assert budget.recover_pending(
        ai_styling_disabled=True, provider_quiescence_confirmed=True
    ) == 1
    state = budget.snapshot()
    assert state.active_reservations == 0
    assert state.charged_units == 400
    assert state.admitted_requests == 1
    assert state.halted


def _race_reserve(path_string: str, units: int, concurrency: int) -> bool:
    budget = StylingBudget(
        Path(path_string),
        monthly_unit_limit=units,
        monthly_request_limit=20,
        max_concurrency=concurrency,
        clock=Clock(),
    )
    try:
        budget.reserve(50, 10)
    except BudgetExceeded:
        return False
    return True


def test_concurrent_threads_cannot_over_admit_global_concurrency(tmp_path):
    budget = make_budget(tmp_path, units=10_000, concurrency=3)
    with ThreadPoolExecutor(max_workers=12) as executor:
        futures = [executor.submit(_race_reserve, str(budget.path), 10_000, 3) for _ in range(20)]
        admitted = sum(future.result() for future in futures)
    assert admitted == 3
    assert budget.snapshot().active_reservations == 3
    assert budget.snapshot().charged_units == 600


def test_independent_processes_cannot_over_admit_monthly_units(tmp_path):
    budget = make_budget(tmp_path, units=600, concurrency=4)
    with ProcessPoolExecutor(max_workers=4, mp_context=get_context("spawn")) as executor:
        futures = [executor.submit(_race_reserve, str(budget.path), 600, 4) for _ in range(12)]
        admitted = sum(future.result() for future in futures)
    assert admitted == 3
    state = reopen(budget).snapshot()
    assert state.charged_units == 600
    assert state.admitted_requests == 3


def test_racing_duplicate_settlement_cannot_double_refund(tmp_path):
    budget = make_budget(tmp_path)
    reservation = budget.reserve(100, 20)

    def settle() -> bool:
        try:
            reopen(budget).complete(reservation, input_tokens=40, output_tokens=10)
        except BudgetUnavailable:
            return False
        return True

    with ThreadPoolExecutor(max_workers=8) as executor:
        assert sum(executor.map(lambda _: settle(), range(16))) == 1
    assert budget.snapshot().charged_units == 180


def test_database_retains_only_two_metadata_tables_and_bounded_pending_rows(tmp_path):
    budget = make_budget(tmp_path)
    for _ in range(20):
        budget.complete(budget.reserve(1, 1), input_tokens=1, output_tokens=1)
    with sqlite3.connect(budget.path) as connection:
        tables = connection.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        assert {row[0] for row in tables} == {"budget_state", "pending_reservations"}
        assert connection.execute("SELECT COUNT(*) FROM budget_state").fetchone()[0] == 1
        assert connection.execute("SELECT COUNT(*) FROM pending_reservations").fetchone()[0] == 0


@pytest.mark.parametrize("mutation", ["permissions", "symlink", "schema", "corrupt"])
def test_untrusted_or_corrupt_database_fails_closed(tmp_path, mutation):
    budget = make_budget(tmp_path)
    if mutation == "permissions":
        budget.path.chmod(0o644)
    elif mutation == "symlink":
        target = budget.path.with_suffix(".original")
        budget.path.rename(target)
        budget.path.symlink_to(target)
    elif mutation == "schema":
        with sqlite3.connect(budget.path) as connection:
            connection.execute("PRAGMA user_version = 999")
    else:
        connection = sqlite3.connect(budget.path)
        connection.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        connection.close()
        budget.path.write_bytes(b"invalid SQLite data")
    with pytest.raises(BudgetUnavailable):
        budget.reserve(1, 1)


def test_exact_envelope_and_private_values_are_absent_from_default_repr(tmp_path):
    budget = make_budget(tmp_path, units=123_456, requests=1234)
    state = budget.snapshot()
    assert "123456" not in repr(state)
    assert "1234" not in repr(state)
    assert "reservation_id" not in repr(budget.reserve(1, 1))


def test_alert_threshold_is_exactly_eighty_percent(tmp_path):
    budget = make_budget(tmp_path, units=1_000)
    budget.finish_failed(budget.reserve(149, 50))
    assert not budget.snapshot().alert_required
    budget.complete(budget.reserve(1, 1), input_tokens=1, output_tokens=0)
    assert budget.snapshot().alert_required


def test_read_only_inspection_never_rolls_period_or_changes_database_or_wal(tmp_path):
    clock = Clock()
    budget = make_budget(tmp_path, clock=clock)
    budget.reserve(100, 20)
    # Keep a writer connection alive so the fixture has committed WAL frames.
    writer = sqlite3.connect(budget.path)
    try:
        writer.execute("UPDATE pending_reservations SET uncertain = 1")
        writer.commit()
        before_db = budget.path.read_bytes()
        wal = Path(str(budget.path) + "-wal")
        before_wal = wal.read_bytes()
        clock.now = OCTOBER
        result = inspect_budget_database(
            budget.path,
            monthly_unit_limit=1_000,
            monthly_request_limit=20,
            max_concurrency=4,
        )
        assert result.month == 202609
        assert result.uncertain_reservations == 1
        assert result.charged_units == 400
        assert budget.path.read_bytes() == before_db
        assert wal.read_bytes() == before_wal
    finally:
        writer.close()


def test_sonnet_default_reservation_and_exact_microdollar_settlement(tmp_path):
    budget = make_budget(tmp_path, units=10_000_000)
    reservation = budget.reserve(1_000_000, 1024)
    state = reopen(budget).snapshot()
    assert state.charged_units == 2_010_240
    assert state.admitted_requests == 1
    assert state.active_reservations == 1
    budget.complete(reservation, input_tokens=1234, output_tokens=567)
    assert budget.snapshot().charged_units == 8_138  # 1234 * 2 + 567 * 10 micro-USD.
    assert budget.snapshot().admitted_requests == 1
    assert budget.snapshot().active_reservations == 0


def test_sonnet_full_output_bound_fits_exactly_without_underreserving(tmp_path):
    budget = make_budget(tmp_path, units=2_020_480)
    reservation = budget.reserve(1_000_000, 2048)
    assert budget.snapshot().charged_units == 2_020_480
    with pytest.raises(BudgetExceeded, match="month_exhausted"):
        budget.reserve(1, 1)
    budget.complete(reservation, input_tokens=1_000_000, output_tokens=2048)
    assert budget.snapshot().charged_units == 2_020_480


def test_sonnet_default_reservation_one_microdollar_short_is_rejected(tmp_path):
    budget = make_budget(tmp_path, units=2_010_239)
    with pytest.raises(BudgetExceeded, match="month_exhausted"):
        budget.reserve(1_000_000, 1024)
    state = budget.snapshot()
    assert state.charged_units == state.admitted_requests == state.active_reservations == 0


@pytest.mark.parametrize("input_bound, output_bound", [(1_000_001, 1024), (1_000_000, 2049)])
def test_sonnet_provider_context_and_output_bounds_fail_before_reservation(
    tmp_path, input_bound, output_bound
):
    budget = make_budget(tmp_path, units=10_000_000)
    with pytest.raises(BudgetUnavailable, match="invalid_limit"):
        budget.reserve(input_bound, output_bound)
    assert budget.snapshot().admitted_requests == 0


def test_sonnet_ledger_pins_model_pricing_unit_and_context_policy(tmp_path):
    budget = make_budget(tmp_path)
    with sqlite3.connect(budget.path) as connection:
        assert connection.execute("PRAGMA user_version").fetchone()[0] == 2
        assert connection.execute(
            "SELECT model, accounting_unit, pricing_policy, input_unit_price, output_unit_price, "
            "input_token_limit, output_token_limit FROM budget_state"
        ).fetchone() == (
            BUDGET_MODEL, BUDGET_UNIT, BUDGET_PRICING_POLICY, INPUT_UNIT_PRICE, OUTPUT_UNIT_PRICE,
            MAX_INPUT_TOKEN_BOUND, MAX_OUTPUT_TOKEN_BOUND,
        ) == (
            "claude-sonnet-5", "usd_microdollar", "global-standard-uncached-v1", 2, 10,
            1_000_000, 2048,
        )


@pytest.mark.parametrize(
    "field, changed",
    [
        ("model", "claude-haiku-4-5-20251001"),
        ("accounting_unit", "input_token"),
        ("pricing_policy", "global-standard-cache-enabled"),
        ("input_unit_price", 1),
        ("output_unit_price", 5),
        ("input_token_limit", 200_000),
        ("output_token_limit", 1024),
    ],
)
def test_changed_pricing_policy_cannot_admit_settle_refund_or_recover(tmp_path, field, changed):
    budget = make_budget(tmp_path)
    reservation = budget.reserve(100, 20)
    with sqlite3.connect(budget.path) as connection:
        # Column names are the fixed parameterized cases above, never user input.
        connection.execute(f"UPDATE budget_state SET {field} = ?", (changed,))
    operations = (
        lambda: reopen(budget),
        lambda: budget.snapshot(),
        lambda: budget.reserve(1, 1),
        lambda: budget.complete(reservation, input_tokens=1, output_tokens=1),
        lambda: budget.finish_failed(reservation),
        lambda: budget.fail(reservation),
        lambda: budget.recover_pending(
            ai_styling_disabled=True, provider_quiescence_confirmed=True
        ),
    )
    for operation in operations:
        with pytest.raises(BudgetUnavailable, match="pricing_mismatch"):
            operation()
    with sqlite3.connect(budget.path) as connection:
        assert connection.execute(
            "SELECT charged_units, admitted_requests FROM budget_state"
        ).fetchone() == (400, 1)
        assert connection.execute("SELECT COUNT(*) FROM pending_reservations").fetchone()[0] == 1


@pytest.mark.parametrize("claimed_version", [1, 2])
def test_old_haiku_ledger_is_never_upgraded_relabelled_reset_or_reprovisioned(
    tmp_path, claimed_version
):
    path = tmp_path / "legacy-budget" / "budget.sqlite3"
    path.parent.mkdir(mode=0o700)
    with sqlite3.connect(path) as connection:
        connection.execute("PRAGMA journal_mode = WAL")
        connection.execute("PRAGMA application_id = 0x57424149")
        connection.executescript("""
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
            INSERT INTO budget_state VALUES (1, 202609, 205120, 1, 10000000, 20, 4, 0);
        """)
        connection.execute(f"PRAGMA user_version = {claimed_version}")
        connection.execute(
            "INSERT INTO pending_reservations VALUES (?, 202609, 200000, 1024, 205120, 1)",
            ("a" * 64,),
        )
    path.chmod(0o600)
    with sqlite3.connect(path) as connection:
        before = list(connection.iterdump())
    with pytest.raises(BudgetUnavailable, match="schema_invalid"):
        StylingBudget(
            path,
            monthly_unit_limit=10_000_000,
            monthly_request_limit=20,
            max_concurrency=4,
            clock=Clock(),
        )
    with pytest.raises(BudgetUnavailable, match="provisioning_failed"):
        initialize_budget_database(
            path,
            monthly_unit_limit=10_000_000,
            monthly_request_limit=20,
            max_concurrency=4,
        )
    with sqlite3.connect(path) as connection:
        assert list(connection.iterdump()) == before
        assert connection.execute("PRAGMA user_version").fetchone()[0] == claimed_version


def test_haiku_priced_pending_charge_is_rejected_even_with_sonnet_header(tmp_path):
    budget = make_budget(tmp_path)
    reservation = budget.reserve(100, 20)
    with sqlite3.connect(budget.path) as connection:
        connection.execute("UPDATE pending_reservations SET charged_units = 200")
        connection.execute("UPDATE budget_state SET charged_units = 200")
    with pytest.raises(BudgetUnavailable, match="accounting_invalid"):
        budget.complete(reservation, input_tokens=0, output_tokens=0)
    with pytest.raises(BudgetUnavailable, match="accounting_invalid"):
        budget.reserve(1, 1)
    with sqlite3.connect(budget.path) as connection:
        assert connection.execute("SELECT charged_units FROM budget_state").fetchone()[0] == 200
        assert connection.execute("SELECT COUNT(*) FROM pending_reservations").fetchone()[0] == 1


def test_concurrent_sonnet_context_reservations_bound_liability_independent_of_workers(tmp_path):
    budget = make_budget(tmp_path, units=10_000_000, concurrency=4)

    def attempt() -> bool:
        process_store = reopen(budget)
        try:
            reservation = process_store.reserve(1_000_000, 1024)
        except BudgetExceeded:
            return False
        # A lost provider response must retain both the full charge and slot.
        process_store.fail(reservation)
        return True

    with ThreadPoolExecutor(max_workers=12) as executor:
        assert sum(executor.map(lambda _: attempt(), range(16))) == 4
    state = reopen(budget).snapshot()
    assert state.charged_units == 8_040_960
    assert state.admitted_requests == state.active_reservations == state.uncertain_reservations == 4
