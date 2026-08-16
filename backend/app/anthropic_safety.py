"""Privacy-safe translation of Anthropic SDK failures at the API boundary."""

from __future__ import annotations

import logging
import re
import threading
from collections.abc import Iterator
from contextlib import contextmanager
from typing import NoReturn

import anthropic
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

_SAFE_REQUEST_ID = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")
MAX_CONCURRENT_ANTHROPIC_REQUESTS = 4
_ANTHROPIC_SLOTS = threading.BoundedSemaphore(MAX_CONCURRENT_ANTHROPIC_REQUESTS)


@contextmanager
def anthropic_request_slot() -> Iterator[None]:
    """Fail fast before synchronous upstream calls can exhaust the worker pool."""
    if not _ANTHROPIC_SLOTS.acquire(blocking=False):
        logger.warning(
            "anthropic_concurrency_rejected limit=%d",
            MAX_CONCURRENT_ANTHROPIC_REQUESTS,
        )
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The AI service is busy; try again shortly.",
            headers={"Retry-After": "1"},
        )
    try:
        yield
    finally:
        _ANTHROPIC_SLOTS.release()


def raise_anthropic_http_error(error: anthropic.APIError) -> NoReturn:
    """Log bounded upstream metadata and hide SDK request/response contents."""
    raw_status = getattr(error, "status_code", None)
    upstream_status = (
        raw_status
        if isinstance(raw_status, int) and 100 <= raw_status <= 599
        else None
    )
    raw_request_id = getattr(error, "request_id", None)
    request_id = (
        raw_request_id
        if isinstance(raw_request_id, str) and _SAFE_REQUEST_ID.fullmatch(raw_request_id)
        else "-"
    )
    logger.warning(
        "anthropic_request_failed type=%s status=%s request_id=%s",
        type(error).__name__,
        upstream_status if upstream_status is not None else "-",
        request_id,
    )

    unavailable = isinstance(error, anthropic.APIConnectionError) or upstream_status == 429
    raise HTTPException(
        status.HTTP_503_SERVICE_UNAVAILABLE if unavailable else status.HTTP_502_BAD_GATEWAY,
        detail="The AI service is temporarily unavailable.",
    ) from error
