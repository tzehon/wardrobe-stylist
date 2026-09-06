"""Fail-closed styling admission; no catalog or provider payload enters storage."""

from __future__ import annotations

import logging
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass, replace
from datetime import UTC, datetime
from pathlib import Path

import anthropic
from fastapi import HTTPException

from app import styling_budget as budget_policy
from app.config import settings
from app.styling_budget import BudgetSnapshot, Reservation, StylingBudget, inspect_budget_database

logger = logging.getLogger(__name__)

# Sonnet 5's entire 1M context is reserved, even though the admitted text is
# much smaller. This avoids treating a local tokenizer estimate as a cost proof.
# No counting endpoint re-transmits the user's catalog. No retries or cache writes.
INPUT_TOKEN_RESERVATION = budget_policy.MAX_INPUT_TOKEN_BOUND
MAX_CATALOG_ITEMS = 200
MAX_COLOR_CHARACTERS = 64
MAX_INPUT_BYTES = 32_768


def _pricing_policy_ready() -> bool:
    """Reject source/configuration drift before admission or a green owner preflight."""
    from app.agents.stylist import MODEL

    return (
        MODEL == budget_policy.BUDGET_MODEL == "claude-sonnet-5"
        and budget_policy.BUDGET_UNIT == "usd_microdollar"
        and budget_policy.BUDGET_PRICING_POLICY == "global-standard-uncached-v1"
        and INPUT_TOKEN_RESERVATION == budget_policy.MAX_INPUT_TOKEN_BOUND == 1_000_000
        and budget_policy.MAX_OUTPUT_TOKEN_BOUND == 2048
        and (budget_policy.INPUT_UNIT_PRICE, budget_policy.OUTPUT_UNIT_PRICE) == (2, 10)
        and all(type(value) is int for value in (
            INPUT_TOKEN_RESERVATION, budget_policy.MAX_INPUT_TOKEN_BOUND,
            budget_policy.MAX_OUTPUT_TOKEN_BOUND, budget_policy.INPUT_UNIT_PRICE,
            budget_policy.OUTPUT_UNIT_PRICE,
        ))
    )


def spend_band(snapshot: BudgetSnapshot) -> str:
    if snapshot.halted or not _pricing_policy_ready():
        return "exhausted"
    reservation_units = (
        INPUT_TOKEN_RESERVATION * budget_policy.INPUT_UNIT_PRICE
        + settings.ai_max_output_tokens * budget_policy.OUTPUT_UNIT_PRICE
    )
    if (
        snapshot.charged_units + reservation_units > snapshot.unit_limit
        or snapshot.admitted_requests >= snapshot.request_limit
    ):
        return "exhausted"
    for percentage, band in ((95, "critical"), (80, "warning")):
        if (
            snapshot.charged_units * 100 >= snapshot.unit_limit * percentage
            or snapshot.admitted_requests * 100 >= snapshot.request_limit * percentage
        ):
            return band
    return "below-warning"


def production_styling_status() -> dict[str, str]:
    """Read-only owner preflight; output fixed bands and no private budget values."""
    from app.dependencies import _ANTHROPIC_MAX_RETRIES

    path = Path(settings.ai_budget_database_path)
    if (
        settings.environment != "production"
        or path != Path("/data/ai-budget/budget.sqlite3")
        or path.resolve() != path
        or not _pricing_policy_ready()
        or _ANTHROPIC_MAX_RETRIES != 0
        or not 256 <= settings.ai_max_output_tokens <= 2048
        or not 1 <= settings.ai_max_concurrency <= 4
    ):
        return {"unavailable": "yes"}
    try:
        snapshot = inspect_budget_database(
            path,
            monthly_unit_limit=settings.ai_monthly_unit_limit,
            monthly_request_limit=settings.ai_monthly_request_limit,
            max_concurrency=settings.ai_max_concurrency,
        )
        now = datetime.now(UTC)
        current_month = now.year * 100 + now.month
        if snapshot.month > current_month:
            return {"unavailable": "yes"}
        band = spend_band(snapshot)
        if (
            snapshot.month < current_month
            and not snapshot.active_reservations
            and not snapshot.halted
        ):
            # The next admission rolls an empty pending set forward atomically.
            band = spend_band(replace(snapshot, charged_units=0, admitted_requests=0))
        return {
            "model": "pinned-sonnet",
            "policy": "bounded",
            "ledger": "ready",
            "spend_band": band,
            "enabled": "yes" if settings.ai_styling_enabled else "no",
            "concurrency": "pending" if snapshot.active_reservations else "clear",
        }
    except Exception:
        return {"unavailable": "yes"}


def unavailable() -> HTTPException:
    return HTTPException(503, detail="The AI service is temporarily unavailable.")


def get_styling_budget() -> StylingBudget:
    if not settings.ai_styling_enabled or not _pricing_policy_ready():
        raise unavailable()
    path = Path(settings.ai_budget_database_path)
    if not settings.ai_budget_database_path or not path.is_absolute():
        raise unavailable()
    if settings.environment.strip().lower() == "production":
        if path != Path("/data/ai-budget/budget.sqlite3"):
            raise unavailable()
    try:
        return StylingBudget(
            path,
            monthly_unit_limit=settings.ai_monthly_unit_limit,
            monthly_request_limit=settings.ai_monthly_request_limit,
            max_concurrency=settings.ai_max_concurrency,
        )
    except Exception:
        logger.warning("styling_budget_event code=store_unavailable")
        raise unavailable() from None


@dataclass
class AdmittedStyling:
    budget: StylingBudget
    reservation: Reservation
    terminal: bool = False
    settled: bool = False

    def complete(
        self,
        *,
        input_tokens: int,
        output_tokens: int,
        cache_creation_input_tokens: int,
        cache_read_input_tokens: int,
    ) -> None:
        # Cache is deliberately off in production. Unexpected accounting data
        # retains the full reservation instead of undercharging the budget.
        counts = (input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens)
        if any(type(value) is not int or value < 0 for value in counts):
            self.terminal = False
            raise unavailable()
        if cache_creation_input_tokens or cache_read_input_tokens:
            self.terminal = False
            raise unavailable()
        try:
            self.budget.complete(
                self.reservation, input_tokens=input_tokens, output_tokens=output_tokens
            )
            self.settled = True
            if self.budget.snapshot().alert_required:
                logger.warning("styling_budget_event code=review_required")
        except Exception:
            self.terminal = False
            logger.warning("styling_budget_event code=settlement_failed")
            raise unavailable() from None


@contextmanager
def admitted_styling() -> Iterator[AdmittedStyling]:
    budget = get_styling_budget()
    try:
        reservation = budget.reserve(INPUT_TOKEN_RESERVATION, settings.ai_max_output_tokens)
    except Exception:
        logger.warning("styling_budget_event code=admission_closed")
        raise unavailable() from None
    call = AdmittedStyling(budget, reservation)
    try:
        yield call
    except anthropic.APIStatusError:
        call.terminal = True
        raise
    finally:
        if not call.settled:
            try:
                if call.terminal:
                    budget.finish_failed(reservation)
                else:
                    budget.fail(reservation)
            except Exception:
                # A committed reservation remains charged if storage fails.
                logger.warning("styling_budget_event code=settlement_failed")
