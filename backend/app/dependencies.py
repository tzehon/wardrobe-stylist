"""Reusable FastAPI dependencies.

`require_device_token` enforces single-user Bearer auth. `get_anthropic_client`
builds the Anthropic SDK client; tests override this via
``app.dependency_overrides`` so no real API call ever leaves the test process.
"""

import anthropic
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import settings

_bearer = HTTPBearer(auto_error=False)


def require_device_token(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> None:
    """Fail closed: if ``DEVICE_TOKEN`` is unset, refuse all requests rather than allow any."""
    if not settings.device_token:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="DEVICE_TOKEN not configured on the backend.",
        )
    if creds is None or creds.credentials != settings.device_token:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            detail="Invalid bearer token.",
        )


def get_anthropic_client() -> anthropic.Anthropic:
    if not settings.anthropic_api_key:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="ANTHROPIC_API_KEY not configured on the backend.",
        )
    return anthropic.Anthropic(api_key=settings.anthropic_api_key)
