"""Process-local construction of the durable App Attest authentication service."""

from functools import lru_cache
from typing import NoReturn

from fastapi import HTTPException

from app.auth.config import AuthConfiguration
from app.auth.service import AppAttestAuthService, AuthFlowError
from app.config import settings


@lru_cache(maxsize=1)
def _load_configuration() -> AuthConfiguration:
    # Configuration safety checks are startup checks. In particular, an
    # expiring production bridge must not be revalidated after its cutoff and
    # take down otherwise-valid App Attest traffic. The service itself checks
    # legacy_allowed() against the current time on every bearer request.
    return AuthConfiguration.from_settings(settings)


@lru_cache(maxsize=1)
def _build_service() -> AppAttestAuthService:
    service = AppAttestAuthService(
        configuration=_load_configuration(),
        legacy_device_token=settings.device_token,
    )
    service.initialize()
    return service


def get_auth_service() -> AppAttestAuthService:
    return _build_service()


def initialize_auth_runtime() -> None:
    """Validate production auth and initialize the durable schema at startup."""
    get_auth_service()


def clear_auth_runtime_cache() -> None:
    """Test seam for settings changes between isolated app clients."""
    _build_service.cache_clear()
    _load_configuration.cache_clear()


def raise_auth_http_error(error: AuthFlowError) -> NoReturn:
    headers = (
        {"Retry-After": str(error.retry_after)}
        if error.retry_after is not None
        else None
    )
    raise HTTPException(
        status_code=error.status_code,
        detail={"code": error.code, "message": error.message},
        headers=headers,
    ) from error
