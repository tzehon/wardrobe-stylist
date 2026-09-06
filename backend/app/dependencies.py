"""Reusable FastAPI dependencies.

`require_backend_identity` accepts a short-lived App Attest session (or the
explicit, expiring migration bridge). `get_anthropic_client` builds the
Anthropic SDK client; tests override this via
``app.dependency_overrides`` so no real API call ever leaves the test process.
"""

from collections.abc import Iterator

import anthropic
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.auth.network import request_client_ip
from app.auth.runtime import get_auth_service, raise_auth_http_error
from app.auth.service import AppAttestAuthService, AuthFlowError, BackendIdentity
from app.config import settings

_bearer = HTTPBearer(auto_error=False)
_ANTHROPIC_TIMEOUT = anthropic.Timeout(
    connect=5.0,
    read=45.0,
    write=10.0,
    pool=1.0,
)
_ANTHROPIC_MAX_RETRIES = 0


def require_backend_identity(
    request: Request,
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    service: AppAttestAuthService = Depends(get_auth_service),
) -> BackendIdentity:
    """Fail closed unless a bearer maps to a live installation session."""
    try:
        return service.authenticate_bearer(
            token=creds.credentials if creds is not None else "",
            path=request.url.path,
            client_ip=request_client_ip(
                request,
                production=service.configuration.deployment_environment == "production",
            ),
        )
    except AuthFlowError as exc:
        raise_auth_http_error(exc)


def get_anthropic_client() -> Iterator[anthropic.Anthropic]:
    if not settings.anthropic_api_key:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="ANTHROPIC_API_KEY not configured on the backend.",
        )
    with anthropic.Anthropic(
        api_key=settings.anthropic_api_key,
        base_url="https://api.anthropic.com",
        timeout=_ANTHROPIC_TIMEOUT,
        max_retries=_ANTHROPIC_MAX_RETRIES,
    ) as client:
        yield client
