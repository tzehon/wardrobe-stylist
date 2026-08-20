"""Process-lifetime auth configuration and service caching tests."""

from dataclasses import replace
from datetime import UTC, datetime, timedelta

import pytest

from app.auth.config import AuthConfiguration
from app.auth.runtime import clear_auth_runtime_cache, get_auth_service
from app.auth.service import AppAttestAuthService, AuthFlowError
from app.config import Settings, settings


def test_cached_bridge_keeps_app_attest_available_after_legacy_cutoff(
    tmp_path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    cutoff = datetime.now(UTC) + timedelta(minutes=5)
    configured_values = {
        "auth_mode": "bridge",
        "environment": "development",
        "device_token": "temporary-legacy-token-value-32-bytes",
        "app_attest_app_id_prefix": "TESTPREFIX",
        "app_attest_bundle_id": "com.tth.Wardrobe",
        "app_attest_environment": "development",
        "app_attest_database_path": str(tmp_path / "private" / "auth.sqlite3"),
        "app_attest_session_secret": "s" * 32,
        "app_attest_allowed_validation_categories": "3",
        "app_attest_allowed_bundle_versions": "7",
        "legacy_bridge_expires_at": cutoff.isoformat(),
    }
    for name, value in configured_values.items():
        monkeypatch.setattr(settings, name, value)

    clear_auth_runtime_cache()
    try:
        service = get_auth_service()
        service._now = lambda: cutoff + timedelta(seconds=1)

        def reject_revalidation(*_args, **_kwargs):
            raise AssertionError("auth configuration was reparsed after startup")

        monkeypatch.setattr(AuthConfiguration, "from_settings", reject_revalidation)
        assert get_auth_service() is service

        challenge = service.issue_challenge(
            purpose="attestation",
            key_id=None,
            client_ip="192.0.2.80",
        )
        assert challenge.challenge

        with pytest.raises(AuthFlowError) as expired:
            service.authenticate_bearer(
                token="temporary-legacy-token-value-32-bytes",
                path="/recommend",
                client_ip="192.0.2.81",
            )
        assert expired.value.code == "invalid_or_expired_session"
    finally:
        clear_auth_runtime_cache()


def test_expired_production_bridge_cold_start_keeps_app_attest_available(tmp_path) -> None:
    now = datetime(2026, 8, 16, tzinfo=UTC)
    legacy_token = "temporary-legacy-token-value-32-bytes"
    production = AuthConfiguration.from_settings(
        Settings(
            _env_file=None,
            auth_mode="bridge",
            environment="production",
            device_token=legacy_token,
            app_attest_app_id_prefix="TESTPREFIX",
            app_attest_bundle_id="com.tth.Wardrobe",
            app_attest_environment="production",
            app_attest_database_path="/data/app-attest/auth.sqlite3",
            app_attest_session_secret="s" * 32,
            app_attest_allowed_validation_categories="2,4",
            app_attest_allowed_bundle_versions="7",
            legacy_bridge_expires_at=(now - timedelta(minutes=1)).isoformat(),
        ),
        now=now,
    )
    service = AppAttestAuthService(
        configuration=replace(
            production,
            database_path=tmp_path / "private" / "auth.sqlite3",
        ),
        legacy_device_token=legacy_token,
        now=lambda: now,
    )
    service.initialize()

    challenge = service.issue_challenge(
        purpose="attestation",
        key_id=None,
        client_ip="192.0.2.90",
    )
    assert challenge.challenge

    with pytest.raises(AuthFlowError) as rejected:
        service.authenticate_bearer(
            token=legacy_token,
            path="/recommend",
            client_ip="192.0.2.91",
        )
    assert rejected.value.status_code == 401
    assert rejected.value.code == "invalid_or_expired_session"
