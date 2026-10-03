"""Separate SQLite connections exercise durable commerce invariants, offline."""

import sqlite3
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from pathlib import Path
from threading import Barrier

import pytest

from app.commerce import store as module
from app.commerce.store import (
    CommerceStore,
    CommerceStoreError,
    ReservationResult,
    initialize_commerce_database,
)
from app.commerce.usage import AllowancePeriod, Outcome, UsageError
from app.schemas.commerce import Plan

NOW = 1790812800  # 2026-10-01T00:00:00Z
OWNER = "a" * 64
OTHER = "b" * 64


@pytest.fixture
def store(tmp_path: Path) -> CommerceStore:
    private = tmp_path / "commerce"
    private.mkdir(mode=0o700)
    path = private / "commerce.sqlite3"
    initialize_commerce_database(path)
    result = CommerceStore(path, clock=lambda: NOW)
    free = AllowancePeriod.free_at(NOW)
    result.activate(OWNER, free, verified_until=free.end)
    return result


def success(store: CommerceStore, owner: str = OWNER) -> str:
    op = store.issue(owner).operation_id
    claim = store.reserve(owner, op)
    assert store.fence_dispatch(owner, op, permit=claim.dispatch_permit)
    store.settle(owner, op, Outcome.SUCCEEDED)
    return op


def race(store: CommerceStore, calls: list[object]) -> list[object]:
    """Start independent workers/connections at the same barrier."""
    barrier = Barrier(len(calls))

    def worker(call: object) -> object:
        assert callable(call)
        independent = CommerceStore(store.path, clock=store.clock)
        barrier.wait(timeout=10)
        try:
            return call(independent)
        except (UsageError, CommerceStoreError) as exc:
            return str(exc)

    with ThreadPoolExecutor(max_workers=len(calls)) as pool:
        return list(pool.map(worker, calls))


def test_restart_restore_and_duplicate_period_keep_balance_and_credit(store: CommerceStore) -> None:
    op = success(store)
    store.credit_delivery(OWNER, op)
    success(store)
    before = store.usage(OWNER)
    reopened = CommerceStore(store.path, clock=store.clock)
    reopened.activate(OWNER, before.period, verified_until=before.period.end)
    assert reopened.usage(OWNER) == before
    assert (before.consumed, before.credits, before.successful) == (1, 1, 2)
    assert reopened.credit_delivery(OWNER, op).delivery_credited
    assert reopened.usage(OWNER) == before


@pytest.mark.parametrize("plan", list(Plan))
def test_allowance_and_one_credit_remain_bounded(store: CommerceStore, plan: Plan) -> None:
    if plan is Plan.PLUS:
        store.activate(OWNER, AllowancePeriod("paid", plan, NOW, NOW + 86400),
                       verified_until=NOW + 86400)
    ops = [success(store) for _ in range(plan.allowance)]
    extra = store.issue(OWNER).operation_id
    with pytest.raises(UsageError, match="quota_exhausted"):
        store.reserve(OWNER, extra)
    store.credit_delivery(OWNER, ops[0])
    claim = store.reserve(OWNER, extra)
    assert store.fence_dispatch(OWNER, extra, permit=claim.dispatch_permit)
    store.settle(OWNER, extra, Outcome.SUCCEEDED)
    assert store.usage(OWNER).remaining == 0
    assert store.usage(OWNER).successful == plan.allowance + 1
    with pytest.raises(UsageError, match="delivery_credit_exhausted"):
        store.credit_delivery(OWNER, extra)


def test_concurrent_last_unit_reservations_have_one_winner(store: CommerceStore) -> None:
    for _ in range(4):
        success(store)
    ops = [store.issue(OWNER).operation_id for _ in range(8)]
    results = race(store, [lambda s, op=op: s.reserve(OWNER, op) for op in ops])
    assert sum(not isinstance(result, str) for result in results) == 1
    assert results.count("operation_pending") == 7
    state = store.usage(OWNER)
    assert (state.consumed, state.reserved, state.remaining) == (4, 1, 0)


def test_duplicate_submission_dispatch_and_settlement_are_once_only(store: CommerceStore) -> None:
    op = store.issue(OWNER).operation_id
    results = race(store, [lambda s: s.reserve(OWNER, op)] * 6)
    claims = [r for r in results if isinstance(r, ReservationResult)]
    permits = [r.dispatch_permit for r in claims if r.dispatch_permit]
    assert len(claims) == 6 and len(permits) == 1
    before = store.usage(OWNER).revision
    dispatches = race(store, [lambda s: s.fence_dispatch(OWNER, op, permit=permits[0])] * 6)
    assert dispatches.count(True) == 1
    assert store.usage(OWNER).revision == before + 1
    assert store.reserve(OWNER, op).operation.state == "dispatched"
    race(store, [lambda s: s.settle(OWNER, op, Outcome.SUCCEEDED)] * 6)
    assert store.usage(OWNER).consumed == 1
    assert store.usage(OWNER).revision == before + 2
    with pytest.raises(UsageError, match="outcome_conflict"):
        store.settle(OWNER, op, Outcome.FAILED)


def test_replay_cannot_dispatch_its_replacement_body(store: CommerceStore) -> None:
    op = store.issue(OWNER).operation_id
    first = store.reserve(OWNER, op)
    duplicate = store.reserve(OWNER, op)
    assert first.dispatch_permit is not None and duplicate.dispatch_permit is None
    assert not store.fence_dispatch(OWNER, op, permit=duplicate.dispatch_permit)
    assert not store.fence_dispatch(OWNER, op, permit="x" * 43)
    assert store.fence_dispatch(OWNER, op, permit=first.dispatch_permit)
    assert first.dispatch_permit not in repr(first)
    with sqlite3.connect(store.path) as db:
        digest = db.execute("SELECT permit_hash FROM operations WHERE id=?", (op,)).fetchone()[0]
    assert digest != first.dispatch_permit


def test_lost_reservation_winner_requires_reconciliation_after_restart(
    store: CommerceStore,
) -> None:
    op = store.issue(OWNER).operation_id
    store.reserve(OWNER, op)  # worker dies before dispatch; permit is lost
    reopened = CommerceStore(store.path, clock=store.clock)
    retry = reopened.reserve(OWNER, op)
    assert retry.operation.state == "reserved" and retry.dispatch_permit is None
    assert not reopened.fence_dispatch(OWNER, op, permit=retry.dispatch_permit)
    assert reopened.usage(OWNER).reserved == 1


def test_concurrent_credits_different_operations_cannot_double_credit(store: CommerceStore) -> None:
    ops = [success(store), success(store)]
    results = race(store, [lambda s, op=op: s.credit_delivery(OWNER, op) for op in ops])
    assert results.count("delivery_credit_exhausted") == 1
    assert (store.usage(OWNER).credits, store.usage(OWNER).consumed) == (1, 1)


def test_concurrent_same_credit_is_idempotent(store: CommerceStore) -> None:
    op = success(store)
    results = race(store, [lambda s: s.credit_delivery(OWNER, op)] * 6)
    assert all(result == results[0] for result in results)
    assert store.usage(OWNER).credits == 1


def test_pending_operation_survives_restart_and_blocks_new_period(store: CommerceStore) -> None:
    op = store.issue(OWNER).operation_id
    claim = store.reserve(OWNER, op)
    assert store.fence_dispatch(OWNER, op, permit=claim.dispatch_permit)
    next_month = store.usage(OWNER).period.end
    reopened = CommerceStore(store.path, clock=lambda: next_month)
    free = AllowancePeriod.free_at(next_month)
    reopened.activate(OWNER, free, verified_until=free.end)
    assert not reopened.fence_dispatch(OWNER, op, permit=claim.dispatch_permit)
    new = reopened.issue(OWNER).operation_id
    with pytest.raises(UsageError, match="operation_pending"):
        reopened.reserve(OWNER, new)
    reopened.settle(OWNER, op, Outcome.SUCCEEDED)
    assert reopened.usage(OWNER).consumed == 0
    with pytest.raises(UsageError, match="entitlement_unavailable"):
        reopened.credit_delivery(OWNER, op)
    reopened.reserve(OWNER, new)
    with sqlite3.connect(store.path) as db:
        state = db.execute("SELECT state FROM operations WHERE id=?", (op,)).fetchone()[0]
        assert state == "succeeded"


def test_credit_replay_after_rollover_does_not_mutate_new_bucket(store: CommerceStore) -> None:
    op = success(store)
    store.credit_delivery(OWNER, op)
    end = store.usage(OWNER).period.end
    store.clock = lambda: end
    new = AllowancePeriod.free_at(end)
    store.activate(OWNER, new, verified_until=new.end)
    before = store.usage(OWNER)
    assert store.credit_delivery(OWNER, op).delivery_credited
    assert store.usage(OWNER) == before


def test_revocation_preserves_settlement_but_denies_admission_and_restore(
    store: CommerceStore,
) -> None:
    period = AllowancePeriod("paid", Plan.PLUS, NOW, NOW + 86400)
    store.activate(OWNER, period, verified_until=period.end)
    op = store.issue(OWNER).operation_id
    claim = store.reserve(OWNER, op)
    assert store.fence_dispatch(OWNER, op, permit=claim.dispatch_permit)
    store.revoke(OWNER, period.period_id)
    store.settle(OWNER, op, Outcome.SUCCEEDED)
    with pytest.raises(UsageError, match="entitlement_unavailable"):
        store.issue(OWNER)
    with pytest.raises(UsageError, match="entitlement_unavailable"):
        store.credit_delivery(OWNER, op)
    with pytest.raises(UsageError, match="period_conflict"):
        store.activate(OWNER, period, verified_until=period.end)


def test_free_reentry_restores_usage_and_owner_revision_never_resets(store: CommerceStore) -> None:
    success(store)
    free = store.usage(OWNER).period
    old_revision = store.usage(OWNER).revision
    paid = AllowancePeriod("paid", Plan.PLUS, NOW, NOW + 100)
    store.activate(OWNER, paid, verified_until=paid.end)
    with pytest.raises(UsageError, match="paid_period_unresolved"):
        store.activate(OWNER, free, verified_until=free.end)
    success(store)
    store.clock = lambda: NOW + 100
    store.activate(OWNER, free, verified_until=free.end)
    restored = store.usage(OWNER)
    assert restored.consumed == 1 and restored.revision > old_revision


@pytest.mark.parametrize("variation", ["alias", "overlap", "shorten", "extend", "stale"])
def test_paid_period_conflicts_fail_without_new_grant(store: CommerceStore, variation: str) -> None:
    paid = AllowancePeriod("paid", Plan.PLUS, NOW, NOW + 1000)
    store.activate(OWNER, paid, verified_until=paid.end)
    before = store.usage(OWNER)
    candidate = {
        "alias": replace(paid, period_id="alias"),
        "overlap": replace(paid, period_id="next", start=NOW + 1),
        "shorten": replace(paid, end=NOW + 900),
        "extend": replace(paid, end=NOW + 1100),
        "stale": paid,
    }[variation]
    if variation == "overlap":
        store.clock = lambda: NOW + 1
    until = candidate.end - (1 if variation == "stale" else 0)
    with pytest.raises(UsageError, match="period_conflict"):
        store.activate(OWNER, candidate, verified_until=until)
    assert store.usage(OWNER).revision == before.revision


def test_freshness_expiry_fails_closed_and_refresh_restores_same_balance(
    store: CommerceStore,
) -> None:
    paid = AllowancePeriod("paid", Plan.PLUS, NOW, NOW + 1000)
    store.activate(OWNER, paid, verified_until=NOW + 10)
    op = store.issue(OWNER).operation_id
    claim = store.reserve(OWNER, op)
    store.clock = lambda: NOW + 10
    with pytest.raises(UsageError, match="entitlement_unavailable"):
        store.fence_dispatch(OWNER, op, permit=claim.dispatch_permit)
    store.activate(OWNER, paid, verified_until=NOW + 100)
    assert store.usage(OWNER).reserved == 1
    assert store.fence_dispatch(OWNER, op, permit=claim.dispatch_permit)


@pytest.mark.parametrize("method", ["operation", "reserve", "fence_dispatch", "credit_delivery"])
def test_cross_owner_and_unknown_handles_are_indistinguishable(
    store: CommerceStore, method: str,
) -> None:
    free = store.usage(OWNER).period
    store.activate(OTHER, free, verified_until=free.end)
    op = success(store)
    for handle in [op, "unknown"]:
        with pytest.raises(UsageError, match="^operation_not_found$"):
            if method == "fence_dispatch":
                store.fence_dispatch(OTHER, handle, permit=None)
            else:
                getattr(store, method)(OTHER, handle)
    with pytest.raises(UsageError, match="^operation_not_found$"):
        store.settle(OTHER, op, Outcome.SUCCEEDED)


def test_expired_issued_handle_never_reserves(store: CommerceStore) -> None:
    op = store.issue(OWNER).operation_id
    store.clock = lambda: NOW + module.HANDLE_TTL
    with pytest.raises(UsageError, match="operation_expired"):
        store.reserve(OWNER, op)
    assert store.usage(OWNER).reserved == 0


def test_failure_releases_quota_without_reopening_dispatch(store: CommerceStore) -> None:
    op = store.issue(OWNER).operation_id
    claim = store.reserve(OWNER, op)
    store.settle(OWNER, op, Outcome.FAILED)  # e.g. global admission denied before dispatch
    assert not store.fence_dispatch(OWNER, op, permit=claim.dispatch_permit)
    assert store.reserve(OWNER, op).operation.state == "failed"
    assert store.usage(OWNER).remaining == 5
    assert store.usage(OWNER).credits == 0


def test_clock_regression_is_owner_wide_even_on_read(store: CommerceStore) -> None:
    store.clock = lambda: NOW + 20
    store.usage(OWNER)
    store.clock = lambda: NOW + 19
    with pytest.raises(UsageError, match="clock_regression"):
        store.issue(OWNER)


def test_revision_exhaustion_rolls_back_operation(store: CommerceStore) -> None:
    with sqlite3.connect(store.path) as db:
        db.execute("UPDATE owners SET revision=?", (module.MAX_REVISION,))
    with pytest.raises(CommerceStoreError, match="revision_exhausted"):
        store.issue(OWNER)
    with sqlite3.connect(store.path) as db:
        assert db.execute("SELECT count(*) FROM operations").fetchone()[0] == 0


@pytest.mark.parametrize("kind", ["missing", "empty", "version", "index", "permissions", "symlink"])
def test_storage_failure_never_recreates_or_repairs(store: CommerceStore, kind: str) -> None:
    if kind == "missing":
        store.path.unlink()
    elif kind == "empty":
        store.path.write_bytes(b"")
    elif kind in ("version", "index"):
        with sqlite3.connect(store.path) as db:
            db.execute("PRAGMA user_version=9" if kind == "version"
                       else "DROP INDEX one_pending_owner")
    elif kind == "permissions":
        store.path.chmod(0o644)
    else:
        original = store.path.with_suffix(".original")
        store.path.rename(original)
        store.path.symlink_to(original)
    with pytest.raises(CommerceStoreError):
        store.usage(OWNER)
    if kind == "missing":
        assert not store.path.exists()
    if kind == "empty":
        assert store.path.stat().st_size == 0


def test_initializer_refuses_existing_file(store: CommerceStore) -> None:
    success(store)
    with pytest.raises(CommerceStoreError, match="provisioning_failed"):
        initialize_commerce_database(store.path)
    assert store.usage(OWNER).consumed == 1


def test_capacity_fails_closed_without_evicting_history(
    store: CommerceStore, monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(module, "MAX_OPERATIONS_PER_PERIOD", 1)
    op = success(store)
    with pytest.raises(CommerceStoreError, match="operation_capacity"):
        store.issue(OWNER)
    assert store.operation(OWNER, op).state == "succeeded"
    monkeypatch.setattr(module, "MAX_OWNERS", 1)
    free = store.usage(OWNER).period
    with pytest.raises(CommerceStoreError, match="owner_capacity"):
        store.activate(OTHER, free, verified_until=free.end)
    monkeypatch.setattr(module, "MAX_PERIODS_PER_OWNER", 1)
    with pytest.raises(CommerceStoreError, match="period_capacity"):
        store.activate(OWNER, AllowancePeriod("paid", Plan.PLUS, NOW, NOW + 100),
                       verified_until=NOW + 100)
    assert store.usage(OWNER).period == free


def test_store_remains_disconnected_from_routes() -> None:
    from app.main import app

    assert all("commerce" not in getattr(route, "path", "") for route in app.routes)
