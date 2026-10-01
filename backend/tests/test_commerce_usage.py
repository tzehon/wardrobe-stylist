"""Quota policy boundaries; these do not claim database/Apple integration."""

from dataclasses import replace
from datetime import UTC, datetime

import pytest

from app.commerce.usage import AllowancePeriod, Operation, Outcome, UsageBucket, UsageError
from app.schemas.commerce import AIAvailability, EntitlementStatus, Plan

NOW = int(datetime(2026, 10, 1, tzinfo=UTC).timestamp())
OWNER = "verified-owner-a"


def bucket(plan: Plan = Plan.FREE) -> UsageBucket:
    period = AllowancePeriod.free_at(NOW)
    if plan is Plan.PLUS:
        period = AllowancePeriod("verified-paid-period", plan, NOW, NOW + 30 * 86400)
    return UsageBucket(OWNER, period, NOW)


def reserve(state: UsageBucket, operation: str) -> UsageBucket:
    return state.reserve(
        owner_key=OWNER, operation_id=operation, now=NOW, entitlement_active=True,
    )


def finish(state: UsageBucket, operation: str, outcome: Outcome = Outcome.SUCCEEDED) -> UsageBucket:
    return state.settle(owner_key=OWNER, operation_id=operation, outcome=outcome, now=NOW)


def credit(state: UsageBucket, operation: str) -> UsageBucket:
    return state.credit_delivery(
        owner_key=OWNER, operation_id=operation, now=NOW, entitlement_active=True,
    )


@pytest.mark.parametrize("plan", list(Plan))
def test_full_allowance_plus_exactly_one_delivery_replacement(plan: Plan) -> None:
    state = bucket(plan)
    for index in range(plan.allowance):
        state = finish(reserve(state, str(index)), str(index))
    assert state.remaining == 0
    with pytest.raises(UsageError, match="quota_exhausted"):
        reserve(state, "too-many")
    state = credit(state, "0")
    assert state.remaining == 1
    state = finish(reserve(state, "replacement"), "replacement")
    assert (state.successful, state.consumed, state.credits, state.remaining) == (
        plan.allowance + 1, plan.allowance, 1, 0,
    )
    assert credit(state, "0") is state
    with pytest.raises(UsageError, match="delivery_credit_exhausted"):
        credit(state, "replacement")
    with pytest.raises(UsageError, match="quota_exhausted"):
        reserve(state, "after-credit")


def test_duplicate_reserve_and_outcome_cannot_spend_twice_or_regenerate() -> None:
    initial = bucket()
    pending = reserve(initial, "one")
    assert initial.remaining == 5  # caller's snapshot was not mutated
    assert reserve(pending, "one") is pending
    with pytest.raises(UsageError, match="operation_pending"):
        reserve(pending, "two")
    complete = finish(pending, "one")
    assert reserve(complete, "one") is complete
    assert finish(complete, "one") is complete
    assert complete.consumed == 1 and complete.revision == 2
    with pytest.raises(UsageError, match="outcome_conflict"):
        finish(complete, "one", Outcome.FAILED)


def test_ordinary_failures_release_reservations_without_using_delivery_credit() -> None:
    state = bucket()
    for index in range(10):
        state = finish(reserve(state, str(index)), str(index), Outcome.FAILED)
        assert (state.remaining, state.credits, state.reserved) == (5, 0, 0)
    assert reserve(state, "0") is state  # failed handle cannot run again
    assert finish(state, "0", Outcome.FAILED) is state
    with pytest.raises(UsageError, match="outcome_conflict"):
        finish(state, "0")
    with pytest.raises(UsageError, match="delivery_credit_ineligible"):
        credit(state, "0")
    state = credit(finish(reserve(state, "success"), "success"), "success")
    assert state.remaining == 5 and state.credits == 1


def test_unknown_and_pending_operations_cannot_receive_credit() -> None:
    with pytest.raises(UsageError, match="operation_not_found"):
        credit(bucket(), "unknown")
    with pytest.raises(UsageError, match="delivery_credit_ineligible"):
        credit(reserve(bucket(), "pending"), "pending")


@pytest.mark.parametrize("action", ["reserve", "settle", "credit_delivery"])
def test_cross_owner_transitions_are_rejected(action: str) -> None:
    state = finish(reserve(bucket(), "one"), "one")
    with pytest.raises(UsageError, match="operation_not_found"):
        if action == "settle":
            state.settle(owner_key="another-owner", operation_id="one",
                         now=NOW, outcome=Outcome.SUCCEEDED)
        else:
            getattr(state, action)(owner_key="another-owner", operation_id="one",
                                   now=NOW, entitlement_active=True)


def test_late_completion_stays_in_original_bucket_and_does_not_credit_new_period() -> None:
    pending = reserve(bucket(), "one")
    next_period = AllowancePeriod.free_at(pending.period.end)
    new = UsageBucket(OWNER, next_period, next_period.start)
    late = pending.settle(owner_key=OWNER, operation_id="one", now=pending.period.end,
                          outcome=Outcome.SUCCEEDED)
    assert late.period == pending.period and late.consumed == 1
    assert new.consumed == 0
    with pytest.raises(UsageError, match="period_expired"):
        late.credit_delivery(owner_key=OWNER, operation_id="one", now=late.period.end,
                             entitlement_active=True)
    with pytest.raises(UsageError, match="operation_not_found"):
        new.credit_delivery(owner_key=OWNER, operation_id="one", now=new.period.start,
                            entitlement_active=True)


def test_credit_replay_after_expiry_or_revocation_does_not_allocate_again() -> None:
    state = credit(finish(reserve(bucket(), "one"), "one"), "one")
    replay = state.credit_delivery(owner_key=OWNER, operation_id="one", now=state.period.end,
                                   entitlement_active=False)
    assert replay is state
    with pytest.raises(UsageError, match="period_expired"):
        state.reserve(owner_key=OWNER, operation_id="new", now=state.period.end,
                      entitlement_active=True)


def test_revocation_blocks_new_admission_and_credit_but_not_settlement() -> None:
    pending = reserve(bucket(Plan.PLUS), "one")
    completed = finish(pending, "one")
    for action, op in [("reserve", "new"), ("credit_delivery", "one")]:
        with pytest.raises(UsageError, match="entitlement_unavailable"):
            getattr(completed, action)(owner_key=OWNER, operation_id=op, now=NOW,
                                       entitlement_active=False)


def test_restored_metadata_preserves_usage_credit_and_replay_outcomes() -> None:
    state = credit(finish(reserve(bucket(Plan.PLUS), "one"), "one"), "one")
    state = finish(reserve(state, "replacement"), "replacement")
    restored = UsageBucket(
        state.owner_key, state.period, state.observed_at, state.revision,
        tuple(
            Operation(op.operation_id, op.outcome, op.delivery_credited)
            for op in state.operations
        ),
    )
    assert (restored.remaining, restored.successful, restored.credits) == (29, 2, 1)
    assert reserve(restored, "replacement") is restored
    with pytest.raises(UsageError, match="delivery_credit_exhausted"):
        credit(restored, "replacement")


@pytest.mark.parametrize("year,month,days", [(2024, 2, 29), (2026, 2, 28), (2026, 12, 31)])
def test_free_periods_use_utc_calendar_boundaries(year: int, month: int, days: int) -> None:
    instant = int(datetime(year, month, 15, 23, 59, tzinfo=UTC).timestamp())
    period = AllowancePeriod.free_at(instant)
    assert datetime.fromtimestamp(period.start, UTC) == datetime(year, month, 1, tzinfo=UTC)
    assert period.end - period.start == days * 86400
    assert AllowancePeriod.free_at(period.end - 1) == period
    assert AllowancePeriod.free_at(period.end).start == period.end


def test_paid_period_is_not_reset_at_utc_month_boundary() -> None:
    start = int(datetime(2026, 9, 15, 11, 23, tzinfo=UTC).timestamp())
    end = int(datetime(2026, 10, 15, 11, 23, tzinfo=UTC).timestamp())
    period = AllowancePeriod("trusted-apple-period", Plan.PLUS, start, end)
    state = UsageBucket(OWNER, period, start)
    state = reserve(state, "october")
    assert (state.period.start, state.period.end, state.remaining) == (start, end, 29)


def test_clock_regression_and_revision_overflow_fail_closed() -> None:
    state = reserve(bucket(), "one")
    with pytest.raises(UsageError, match="clock_regression"):
        state.settle(owner_key=OWNER, operation_id="one", now=NOW - 1, outcome=Outcome.SUCCEEDED)
    with pytest.raises(UsageError, match="invalid_integer"):
        reserve(replace(bucket(), revision=9_007_199_254_740_991), "overflow")


@pytest.mark.parametrize("operations", [
    (Operation("same"), Operation("same")),
    (Operation("one"), Operation("two")),
    tuple(Operation(str(i), Outcome.SUCCEEDED) for i in range(6)),
    (Operation("one", Outcome.SUCCEEDED, True), Operation("two", Outcome.SUCCEEDED, True)),
])
def test_inconsistent_restored_metadata_is_rejected(operations: tuple[Operation, ...]) -> None:
    with pytest.raises(UsageError):
        replace(bucket(), operations=operations)


def test_snapshot_includes_net_and_gross_usage_without_identity_or_content() -> None:
    state = credit(finish(reserve(bucket(), "one"), "one"), "one")
    usage = state.snapshot(now=NOW, entitlement_status=EntitlementStatus.ACTIVE,
                           ai_availability=AIAvailability.SERVICE_PAUSED)
    assert (usage.successful_generations, usage.consumed, usage.remaining) == (1, 0, 5)
    wire = usage.model_dump_json()
    assert OWNER not in wire and "operation_id" not in wire


def test_no_commerce_routes_are_exposed_by_this_slice() -> None:
    from app.main import app

    assert not any(path.startswith(("/commerce", "/v2")) for path in app.openapi()["paths"])
