"""Validated configuration for App Attest authentication.

The process stays import-safe so tests and developer tooling don't need release
secrets. Production startup rejects legacy mode; bridge mode requires an
explicit, tightly bounded expiry before it can temporarily protect a rollout.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Literal, cast

from app.config import Settings

AuthMode = Literal["legacy", "bridge", "app_attest"]
AppAttestEnvironment = Literal["development", "production"]
DeploymentEnvironment = Literal["dev", "development", "test", "production"]

_APP_ID_PREFIX = re.compile(r"^[A-Z0-9]+$")
_BUNDLE_ID = re.compile(r"^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$")


class AuthConfigurationError(RuntimeError):
    """Raised when authentication would start in an unsafe configuration."""


def _csv_strings(value: str) -> frozenset[str]:
    return frozenset(part.strip() for part in value.split(",") if part.strip())


def _csv_ints(value: str, *, field: str) -> frozenset[int]:
    try:
        return frozenset(int(part) for part in _csv_strings(value))
    except ValueError as exc:
        raise AuthConfigurationError(f"{field} must be a comma-separated integer list.") from exc


def _utc_datetime(value: str, *, field: str) -> datetime:
    raw = value.strip()
    if not raw:
        raise AuthConfigurationError(f"{field} is required.")
    try:
        parsed = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    except ValueError as exc:
        raise AuthConfigurationError(f"{field} must be an RFC 3339 timestamp.") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != UTC.utcoffset(parsed):
        raise AuthConfigurationError(f"{field} must include an explicit UTC offset.")
    return parsed.astimezone(UTC)


@dataclass(frozen=True)
class AuthConfiguration:
    mode: AuthMode
    deployment_environment: DeploymentEnvironment
    app_id_prefix: str
    bundle_id: str
    app_attest_environment: AppAttestEnvironment
    database_path: Path | None
    session_secret: bytes = field(repr=False)
    allowed_validation_categories: frozenset[int]
    allowed_bundle_versions: frozenset[str]
    legacy_bridge_expires_at: datetime | None
    challenge_ttl_seconds: int
    session_ttl_seconds: int
    challenge_rate_limit_per_minute: int
    registration_rate_limit_per_hour: int
    session_rate_limit_per_hour: int
    recommend_rate_limit_per_hour: int

    @property
    def app_id(self) -> str:
        return f"{self.app_id_prefix}.{self.bundle_id}"

    @property
    def app_attest_enabled(self) -> bool:
        return self.mode in {"bridge", "app_attest"}

    def legacy_allowed(self, *, now: datetime) -> bool:
        if self.mode == "legacy":
            return self.deployment_environment.lower() != "production"
        return (
            self.mode == "bridge"
            and self.legacy_bridge_expires_at is not None
            and now.astimezone(UTC) < self.legacy_bridge_expires_at
        )

    @classmethod
    def from_settings(
        cls,
        settings: Settings,
        *,
        now: datetime | None = None,
    ) -> AuthConfiguration:
        raw_deployment_environment = settings.environment.strip().lower()
        if raw_deployment_environment not in {
            "dev",
            "development",
            "test",
            "production",
        }:
            raise AuthConfigurationError(
                "ENVIRONMENT must be dev, development, test, or production."
            )
        deployment_environment = cast(
            DeploymentEnvironment,
            raw_deployment_environment,
        )

        raw_mode = settings.auth_mode.strip().lower()
        if raw_mode not in {"legacy", "bridge", "app_attest"}:
            raise AuthConfigurationError("AUTH_MODE must be legacy, bridge, or app_attest.")
        mode = cast(AuthMode, raw_mode)
        production = deployment_environment == "production"
        if production and mode == "legacy":
            raise AuthConfigurationError("AUTH_MODE=legacy is forbidden in production.")

        bridge_expiry = None
        if mode == "bridge":
            if len(settings.device_token.encode("utf-8")) < 32:
                raise AuthConfigurationError(
                    "DEVICE_TOKEN must contain at least 32 UTF-8 bytes in bridge mode."
                )
            bridge_expiry = _utc_datetime(
                settings.legacy_bridge_expires_at,
                field="LEGACY_BRIDGE_EXPIRES_AT",
            )
            checked_at = (now or datetime.now(UTC)).astimezone(UTC)
            if production and bridge_expiry > checked_at + timedelta(days=7):
                raise AuthConfigurationError(
                    "Production LEGACY_BRIDGE_EXPIRES_AT must not be more than 7 days away."
                )

        app_id_prefix = settings.app_attest_app_id_prefix.strip()
        bundle_id = settings.app_attest_bundle_id.strip()
        raw_attest_environment = settings.app_attest_environment.strip().lower()
        if raw_attest_environment not in {"development", "production"}:
            raise AuthConfigurationError(
                "APP_ATTEST_ENVIRONMENT must be development or production."
            )
        attest_environment = cast(AppAttestEnvironment, raw_attest_environment)

        database_path: Path | None = None
        session_secret = b""
        categories: frozenset[int] = frozenset()
        bundle_versions: frozenset[str] = frozenset()
        if mode in {"bridge", "app_attest"}:
            if not _APP_ID_PREFIX.fullmatch(app_id_prefix):
                raise AuthConfigurationError("APP_ATTEST_APP_ID_PREFIX is invalid.")
            if not _BUNDLE_ID.fullmatch(bundle_id):
                raise AuthConfigurationError("APP_ATTEST_BUNDLE_ID is invalid.")
            if production and attest_environment != "production":
                raise AuthConfigurationError(
                    "Production deployments require APP_ATTEST_ENVIRONMENT=production."
                )

            raw_path = settings.app_attest_database_path.strip()
            if not raw_path:
                raise AuthConfigurationError("APP_ATTEST_DATABASE_PATH is required.")
            database_path = Path(raw_path)
            if not database_path.is_absolute():
                raise AuthConfigurationError("APP_ATTEST_DATABASE_PATH must be absolute.")
            # Canonicalize the directory for containment checks, but preserve
            # the final path component. Resolving the complete path would turn
            # an existing database-file symlink into its target before
            # ``AuthStore`` can reject that symlink with ``lstat``.
            database_path = database_path.parent.resolve(strict=False) / database_path.name
            filesystem_root = Path(database_path.anchor).resolve(strict=False)
            if database_path.parent in {filesystem_root, Path.home().resolve(strict=False)}:
                raise AuthConfigurationError(
                    "APP_ATTEST_DATABASE_PATH must use a dedicated private directory."
                )
            # These temporary-directory literals are rejection targets, never
            # locations used to create sensitive files. Keep the Bandit
            # suppression on the flagged literal so it cannot mask this branch.
            if database_path.parent in {
                Path("/tmp"),  # nosec B108
                Path("/private/tmp"),
            }:
                raise AuthConfigurationError(
                    "APP_ATTEST_DATABASE_PATH must use a dedicated private directory."
                )
            if production:
                data_root = Path("/data").resolve(strict=False)
                if (
                    database_path.parent == data_root
                    or not database_path.parent.is_relative_to(data_root)
                ):
                    raise AuthConfigurationError(
                        "Production APP_ATTEST_DATABASE_PATH must use a private directory "
                        "strictly below /data."
                    )

            session_secret = settings.app_attest_session_secret.encode("utf-8")
            if len(session_secret) < 32:
                raise AuthConfigurationError(
                    "APP_ATTEST_SESSION_SECRET must contain at least 32 UTF-8 bytes."
                )

            categories = _csv_ints(
                settings.app_attest_allowed_validation_categories,
                field="APP_ATTEST_ALLOWED_VALIDATION_CATEGORIES",
            )
            expected_categories = {2, 4} if attest_environment == "production" else {3}
            if not categories or not categories.issubset(expected_categories):
                expected = "2 and/or 4" if attest_environment == "production" else "3"
                raise AuthConfigurationError(
                    "APP_ATTEST_ALLOWED_VALIDATION_CATEGORIES must contain only " + expected + "."
                )
            bundle_versions = _csv_strings(settings.app_attest_allowed_bundle_versions)
            if not bundle_versions:
                raise AuthConfigurationError(
                    "APP_ATTEST_ALLOWED_BUNDLE_VERSIONS requires an exact allowlist."
                )

        positive_limits = {
            "APP_ATTEST_CHALLENGE_RATE_LIMIT_PER_MINUTE": (
                settings.app_attest_challenge_rate_limit_per_minute
            ),
            "APP_ATTEST_REGISTRATION_RATE_LIMIT_PER_HOUR": (
                settings.app_attest_registration_rate_limit_per_hour
            ),
            "APP_ATTEST_SESSION_RATE_LIMIT_PER_HOUR": (
                settings.app_attest_session_rate_limit_per_hour
            ),
            "APP_ATTEST_RECOMMEND_RATE_LIMIT_PER_HOUR": (
                settings.app_attest_recommend_rate_limit_per_hour
            ),
        }
        for name, value in positive_limits.items():
            if value <= 0:
                raise AuthConfigurationError(f"{name} must be positive.")
        if not 60 <= settings.app_attest_challenge_ttl_seconds <= 300:
            raise AuthConfigurationError(
                "APP_ATTEST_CHALLENGE_TTL_SECONDS must be between 60 and 300."
            )
        if not 60 <= settings.app_session_ttl_seconds <= 900:
            raise AuthConfigurationError("APP_SESSION_TTL_SECONDS must be between 60 and 900.")

        return cls(
            mode=mode,
            deployment_environment=deployment_environment,
            app_id_prefix=app_id_prefix,
            bundle_id=bundle_id,
            app_attest_environment=attest_environment,
            database_path=database_path,
            session_secret=session_secret,
            allowed_validation_categories=categories,
            allowed_bundle_versions=bundle_versions,
            legacy_bridge_expires_at=bridge_expiry,
            challenge_ttl_seconds=settings.app_attest_challenge_ttl_seconds,
            session_ttl_seconds=settings.app_session_ttl_seconds,
            challenge_rate_limit_per_minute=settings.app_attest_challenge_rate_limit_per_minute,
            registration_rate_limit_per_hour=settings.app_attest_registration_rate_limit_per_hour,
            session_rate_limit_per_hour=settings.app_attest_session_rate_limit_per_hour,
            recommend_rate_limit_per_hour=settings.app_attest_recommend_rate_limit_per_hour,
        )
