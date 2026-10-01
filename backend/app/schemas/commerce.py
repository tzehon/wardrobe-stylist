"""Inactive usage snapshot contract; no Apple verification or route is installed.

JSON Schema defines the wire shape. Cross-field arithmetic and period checks
are also enforced here and by the Swift decoder. Neither model grants access.
"""

from enum import StrEnum
from typing import Annotated, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

MAX_REVISION = 9_007_199_254_740_991
MAX_TIMESTAMP = 253_402_300_799

Count = Annotated[int, Field(strict=True, ge=0, le=31)]
Timestamp = Annotated[int, Field(strict=True, ge=0, le=MAX_TIMESTAMP)]


class Plan(StrEnum):
    FREE = "free"
    PLUS = "plus"

    @property
    def allowance(self) -> int:
        return 5 if self is Plan.FREE else 30


class EntitlementStatus(StrEnum):
    ACTIVE = "active"
    GRACE = "grace"
    EXPIRED = "expired"
    REVOKED = "revoked"
    VERIFICATION_REQUIRED = "verification_required"


class AIAvailability(StrEnum):
    AVAILABLE = "available"
    SERVICE_PAUSED = "service_paused"
    VERIFICATION_REQUIRED = "verification_required"


class CommerceUsage(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    plan: Plan
    allowance: Annotated[int, Field(strict=True, ge=5, le=30)]
    successful_generations: Count
    delivery_credits_used: Annotated[int, Field(strict=True, ge=0, le=1)]
    consumed: Count
    reserved: Annotated[int, Field(strict=True, ge=0, le=1)]
    remaining: Count
    period_start: Timestamp
    period_end: Timestamp
    revision: Annotated[int, Field(strict=True, ge=0, le=MAX_REVISION)]
    server_time: Timestamp
    entitlement_status: EntitlementStatus
    ai_availability: AIAvailability

    @model_validator(mode="after")
    def consistent_usage(self) -> Self:
        if self.allowance != self.plan.allowance:
            raise ValueError("commerce_allowance_mismatch")
        if self.consumed != self.successful_generations - self.delivery_credits_used:
            raise ValueError("commerce_consumption_mismatch")
        if self.remaining != self.allowance - self.consumed - self.reserved:
            raise ValueError("commerce_balance_mismatch")
        if not self.period_start < self.period_end or self.server_time < self.period_start:
            raise ValueError("commerce_period_invalid")
        usable = self.entitlement_status in (EntitlementStatus.ACTIVE, EntitlementStatus.GRACE)
        if usable and self.server_time >= self.period_end:
            raise ValueError("commerce_entitlement_expired")
        if self.plan is Plan.FREE and self.entitlement_status is EntitlementStatus.GRACE:
            raise ValueError("commerce_free_grace_invalid")
        if self.ai_availability is AIAvailability.AVAILABLE and not usable:
            raise ValueError("commerce_availability_mismatch")
        return self
