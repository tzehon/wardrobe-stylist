"""Pure, immutable quota transitions for already verified ownership/periods.

This module neither verifies Apple evidence nor stores state or calls a provider.
A future transactional store MUST load the authoritative owner/period, enforce
cross-period outstanding-operation exclusion, and commit a transition with a
revision compare-and-swap. Two transitions on the same snapshot are NOT atomic.
Operation creation/expiry, dispatch fencing and global liability are separate.
"""

from dataclasses import dataclass, replace
from datetime import UTC, datetime
from enum import StrEnum

from app.schemas.commerce import (
    MAX_REVISION,
    MAX_TIMESTAMP,
    AIAvailability,
    CommerceUsage,
    EntitlementStatus,
    Plan,
)


class UsageError(ValueError):
    """Fixed codes only: never include ownership or submitted content."""


def _integer(value: int, maximum: int = MAX_TIMESTAMP) -> None:
    if type(value) is not int or not 0 <= value <= maximum:
        raise UsageError("invalid_integer")


def _identifier(value: str) -> None:
    if type(value) is not str or not 1 <= len(value) <= 128:
        raise UsageError("invalid_identifier")


def _free_boundaries(now: int) -> tuple[int, int]:
    _integer(now)
    instant = datetime.fromtimestamp(now, UTC)
    start = datetime(instant.year, instant.month, 1, tzinfo=UTC)
    if instant.year == 9999 and instant.month == 12:
        raise UsageError("unsupported_period")
    end = datetime(
        instant.year + (instant.month == 12), instant.month % 12 + 1, 1, tzinfo=UTC,
    )
    return int(start.timestamp()), int(end.timestamp())


@dataclass(frozen=True)
class AllowancePeriod:
    """Plus values must come from a future trusted Apple adapter, never raw input."""

    period_id: str
    plan: Plan
    start: int
    end: int

    def __post_init__(self) -> None:
        _identifier(self.period_id)
        _integer(self.start)
        _integer(self.end)
        if not isinstance(self.plan, Plan) or self.start >= self.end:
            raise UsageError("invalid_period")
        if self.plan is Plan.FREE and (self.start, self.end) != _free_boundaries(self.start):
            raise UsageError("invalid_free_period")

    @classmethod
    def free_at(cls, now: int) -> "AllowancePeriod":
        start, end = _free_boundaries(now)
        # The future store uses unique (owner, plan, period boundaries), not a
        # caller-supplied identifier, when finding or restoring this bucket.
        return cls(f"free:{start}", Plan.FREE, start, end)


class Outcome(StrEnum):
    PENDING = "pending"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


@dataclass(frozen=True)
class Operation:
    operation_id: str
    outcome: Outcome = Outcome.PENDING
    delivery_credited: bool = False

    def __post_init__(self) -> None:
        _identifier(self.operation_id)
        if not isinstance(self.outcome, Outcome) or type(self.delivery_credited) is not bool:
            raise UsageError("invalid_operation")
        if self.delivery_credited and self.outcome is not Outcome.SUCCEEDED:
            raise UsageError("invalid_credit")


@dataclass(frozen=True)
class UsageBucket:
    """One period's metadata-only state, including replay outcomes.

    Construction of an empty bucket is not entitlement issuance. A future store
    must restore an existing bucket for this owner/period rather than create a
    new one on purchase replay, reinstall, plan switching or restore.
    """

    owner_key: str
    period: AllowancePeriod
    observed_at: int
    revision: int = 0
    operations: tuple[Operation, ...] = ()

    def __post_init__(self) -> None:
        _identifier(self.owner_key)
        _integer(self.observed_at)
        _integer(self.revision, MAX_REVISION)
        if not isinstance(self.period, AllowancePeriod) or self.observed_at < self.period.start:
            raise UsageError("invalid_bucket")
        if type(self.operations) is not tuple or any(
            not isinstance(op, Operation) for op in self.operations
        ):
            raise UsageError("invalid_operations")
        if len({op.operation_id for op in self.operations}) != len(self.operations):
            raise UsageError("duplicate_operation")
        if self.credits > 1 or self.reserved > 1 or self.consumed + self.reserved > self.allowance:
            raise UsageError("invalid_balance")

    @property
    def allowance(self) -> int:
        return self.period.plan.allowance

    @property
    def successful(self) -> int:
        return sum(op.outcome is Outcome.SUCCEEDED for op in self.operations)

    @property
    def credits(self) -> int:
        return sum(op.delivery_credited for op in self.operations)

    @property
    def consumed(self) -> int:
        return self.successful - self.credits

    @property
    def reserved(self) -> int:
        return sum(op.outcome is Outcome.PENDING for op in self.operations)

    @property
    def remaining(self) -> int:
        return self.allowance - self.consumed - self.reserved

    def _authorize(self, owner_key: str, now: int) -> None:
        _integer(now)
        if owner_key != self.owner_key:
            raise UsageError("operation_not_found")
        if now < self.observed_at:
            raise UsageError("clock_regression")

    def _usable(self, now: int, entitlement_active: bool) -> None:
        if entitlement_active is not True:
            raise UsageError("entitlement_unavailable")
        if not self.period.start <= now < self.period.end:
            raise UsageError("period_expired")

    def _operation(self, operation_id: str) -> Operation:
        for op in self.operations:
            if op.operation_id == operation_id:
                return op
        raise UsageError("operation_not_found")

    def _update(self, operation: Operation, now: int, *, append: bool = False) -> "UsageBucket":
        operations = (
            (*self.operations, operation) if append else tuple(
                operation if op.operation_id == operation.operation_id else op
                for op in self.operations
            )
        )
        return replace(self, operations=operations, observed_at=now, revision=self.revision + 1)

    def reserve(
        self, *, owner_key: str, operation_id: str, now: int, entitlement_active: bool,
    ) -> "UsageBucket":
        """Existing handles return their outcome; they never reserve again.

        Caller must establish that a NEW handle was issued by the server for
        this owner/period and is unexpired. This is not a public request parser.
        """
        self._authorize(owner_key, now)
        _identifier(operation_id)
        if any(op.operation_id == operation_id for op in self.operations):
            return self
        self._usable(now, entitlement_active)
        if self.reserved:
            raise UsageError("operation_pending")
        if self.remaining == 0:
            raise UsageError("quota_exhausted")
        return self._update(Operation(operation_id), now, append=True)

    def settle(
        self, *, owner_key: str, operation_id: str, outcome: Outcome, now: int,
    ) -> "UsageBucket":
        """Caller establishes the durable result/quiescence, not client input.

        Settle in the ORIGINAL period even after expiry or revocation; a future
        store must not redirect a late completion to a new allowance bucket.
        """
        self._authorize(owner_key, now)
        if outcome not in (Outcome.SUCCEEDED, Outcome.FAILED) or not isinstance(outcome, Outcome):
            raise UsageError("invalid_outcome")
        op = self._operation(operation_id)
        if op.outcome is outcome:
            return self
        if op.outcome is not Outcome.PENDING:
            raise UsageError("outcome_conflict")
        return self._update(replace(op, outcome=outcome), now)

    def credit_delivery(
        self, *, owner_key: str, operation_id: str, now: int, entitlement_active: bool,
    ) -> "UsageBucket":
        self._authorize(owner_key, now)
        op = self._operation(operation_id)
        # Replay is harmless even after expiry/revocation; do not grant again.
        if op.delivery_credited:
            return self
        self._usable(now, entitlement_active)
        if op.outcome is not Outcome.SUCCEEDED:
            raise UsageError("delivery_credit_ineligible")
        if self.credits:
            raise UsageError("delivery_credit_exhausted")
        return self._update(replace(op, delivery_credited=True), now)

    def snapshot(
        self, *, now: int, entitlement_status: EntitlementStatus, ai_availability: AIAvailability,
    ) -> CommerceUsage:
        _integer(now)
        if now < self.observed_at:
            raise UsageError("clock_regression")
        return CommerceUsage(
            plan=self.period.plan, allowance=self.allowance,
            successful_generations=self.successful, delivery_credits_used=self.credits,
            consumed=self.consumed, reserved=self.reserved, remaining=self.remaining,
            period_start=self.period.start, period_end=self.period.end,
            revision=self.revision, server_time=now,
            entitlement_status=entitlement_status, ai_availability=ai_availability,
        )
