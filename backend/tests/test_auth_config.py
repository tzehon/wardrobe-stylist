"""Fail-closed configuration tests for production App Attest auth."""

import tomllib
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest
import yaml

from app.auth.config import AuthConfiguration, AuthConfigurationError
from app.auth.store import AuthStore
from app.config import Settings

NOW = datetime(2026, 8, 16, 0, 0, tzinfo=UTC)


def test_production_rejects_legacy_mode() -> None:
    with pytest.raises(AuthConfigurationError, match="legacy is forbidden"):
        AuthConfiguration.from_settings(
            _settings(auth_mode="legacy", environment="production"),
            now=NOW,
        )


def test_unknown_deployment_environment_is_rejected() -> None:
    with pytest.raises(AuthConfigurationError, match="ENVIRONMENT must be"):
        AuthConfiguration.from_settings(
            _settings(auth_mode="legacy", environment="prod"),
            now=NOW,
        )


def test_sensitive_settings_and_auth_secret_are_redacted_from_repr(tmp_path) -> None:
    api_key = "private-anthropic-key-sentinel"
    device_token = "private-device-token-sentinel-value"
    session_secret = "private-session-secret-sentinel-value"
    raw_settings = _settings(
        anthropic_api_key=api_key,
        device_token=device_token,
        app_attest_session_secret=session_secret,
        app_attest_database_path=str(tmp_path / "private" / "auth.sqlite3"),
    )

    assert api_key not in repr(raw_settings)
    assert device_token not in repr(raw_settings)
    assert session_secret not in repr(raw_settings)

    configuration = AuthConfiguration.from_settings(raw_settings, now=NOW)
    assert session_secret not in repr(configuration)


def test_production_bridge_requires_near_future_utc_cutoff() -> None:
    valid = AuthConfiguration.from_settings(
        _settings(
            auth_mode="bridge",
            environment="production",
            app_attest_environment="production",
            app_attest_database_path="/data/private/auth.sqlite3",
            app_attest_allowed_validation_categories="2,4",
            legacy_bridge_expires_at=(NOW + timedelta(days=2)).isoformat(),
        ),
        now=NOW,
    )
    assert valid.legacy_allowed(now=NOW)
    assert not valid.legacy_allowed(now=NOW + timedelta(days=3))

    expired = AuthConfiguration.from_settings(
        _settings(
            auth_mode="bridge",
            environment="production",
            app_attest_environment="production",
            app_attest_database_path="/data/private/auth.sqlite3",
            app_attest_allowed_validation_categories="2,4",
            legacy_bridge_expires_at=(NOW - timedelta(seconds=1)).isoformat(),
        ),
        now=NOW,
    )
    assert not expired.legacy_allowed(now=NOW)

    with pytest.raises(AuthConfigurationError, match="must not be more than 7 days"):
        AuthConfiguration.from_settings(
            _settings(
                auth_mode="bridge",
                environment="production",
                app_attest_environment="production",
                app_attest_database_path="/data/private/auth.sqlite3",
                app_attest_allowed_validation_categories="2,4",
                legacy_bridge_expires_at=(NOW + timedelta(days=8)).isoformat(),
            ),
            now=NOW,
        )


def test_bridge_requires_strong_legacy_token() -> None:
    with pytest.raises(AuthConfigurationError, match="DEVICE_TOKEN must contain at least 32"):
        AuthConfiguration.from_settings(
            _settings(
                auth_mode="bridge",
                device_token="too-short",
                legacy_bridge_expires_at=(NOW + timedelta(days=1)).isoformat(),
            ),
            now=NOW,
        )


@pytest.mark.parametrize(
    "path",
    [
        "/data",
        "/data/auth.sqlite3",
        "/data/../tmp/auth.sqlite3",
        "/tmp/auth.sqlite3",
    ],
)
def test_production_database_must_be_strictly_below_data(path: str) -> None:
    with pytest.raises(AuthConfigurationError, match="APP_ATTEST_DATABASE_PATH"):
        AuthConfiguration.from_settings(
            _settings(
                auth_mode="app_attest",
                environment="production",
                app_attest_environment="production",
                app_attest_database_path=path,
                app_attest_allowed_validation_categories="2,4",
            ),
            now=NOW,
        )


def test_database_path_rejects_filesystem_root_parent() -> None:
    with pytest.raises(AuthConfigurationError, match="dedicated private directory"):
        AuthConfiguration.from_settings(
            _settings(app_attest_database_path="/auth.sqlite3"),
            now=NOW,
        )


def test_configuration_preserves_database_symlink_for_store_rejection(tmp_path) -> None:
    parent = tmp_path / "private"
    parent.mkdir(mode=0o700)
    target = parent / "target.sqlite3"
    target.touch(mode=0o600)
    database_path = parent / "auth.sqlite3"
    database_path.symlink_to(target)

    configuration = AuthConfiguration.from_settings(
        _settings(app_attest_database_path=str(database_path)),
        now=NOW,
    )

    assert configuration.database_path == parent.resolve() / database_path.name
    assert configuration.database_path.is_symlink()
    with pytest.raises(PermissionError, match="must not be a symlink"):
        AuthStore(configuration.database_path).initialize()


def test_app_id_uses_confirmed_prefix_not_inferred_team_id(tmp_path) -> None:
    config = AuthConfiguration.from_settings(
        _settings(
            auth_mode="app_attest",
            app_attest_app_id_prefix="CUSTOMPREFIX",
            app_attest_database_path=str(tmp_path / "private" / "auth.sqlite3"),
        ),
        now=NOW,
    )
    assert config.app_id == "CUSTOMPREFIX.com.tth.Wardrobe"


def test_fly_auth_database_uses_dedicated_volume_directory() -> None:
    repository_root = Path(__file__).parents[2]
    fly_config = tomllib.loads(
        (Path(__file__).parents[1] / "fly.toml").read_text(encoding="utf-8")
    )
    ios_project = yaml.safe_load(
        (repository_root / "ios" / "project.yml").read_text(encoding="utf-8")
    )
    database_path = Path(fly_config["env"]["APP_ATTEST_DATABASE_PATH"]).resolve(
        strict=False
    )
    data_root = Path("/data").resolve(strict=False)
    accepted_builds = {
        value.strip()
        for value in fly_config["env"]["APP_ATTEST_ALLOWED_BUNDLE_VERSIONS"].split(",")
        if value.strip()
    }
    current_build = str(ios_project["settings"]["base"]["CURRENT_PROJECT_VERSION"])

    assert fly_config["mounts"]["destination"] == "/data"
    assert database_path.parent != data_root
    assert database_path.parent.is_relative_to(data_root)
    assert fly_config["env"]["AUTH_MODE"] == "app_attest"
    assert fly_config["env"]["APP_ATTEST_ENVIRONMENT"] == "production"
    assert fly_config["env"]["APP_ATTEST_APP_ID_PREFIX"] == "29NT767Y9P"
    assert fly_config["env"]["APP_ATTEST_BUNDLE_ID"] == "com.tth.Wardrobe"
    assert fly_config["env"]["APP_ATTEST_ALLOWED_VALIDATION_CATEGORIES"] == "2"
    assert current_build in accepted_builds
    assert fly_config["http_service"]["min_machines_running"] == 1


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("app_attest_challenge_ttl_seconds", 301, "between 60 and 300"),
        ("app_session_ttl_seconds", 901, "between 60 and 900"),
    ],
)
def test_auth_ttls_cannot_exceed_retention_policy(
    field: str,
    value: int,
    message: str,
) -> None:
    with pytest.raises(AuthConfigurationError, match=message):
        AuthConfiguration.from_settings(_settings(**{field: value}), now=NOW)


def _settings(**overrides: object) -> Settings:
    values: dict[str, object] = {
        "auth_mode": "app_attest",
        "environment": "dev",
        "device_token": "legacy-bridge-token-value-32-bytes",
        "app_attest_app_id_prefix": "TESTPREFIX",
        "app_attest_bundle_id": "com.tth.Wardrobe",
        "app_attest_environment": "development",
        "app_attest_database_path": "/tmp/wardrobe-tests/auth.sqlite3",
        "app_attest_session_secret": "s" * 32,
        "app_attest_allowed_validation_categories": "3",
        "app_attest_allowed_bundle_versions": "7",
    }
    values.update(overrides)
    return Settings(_env_file=None, **values)
