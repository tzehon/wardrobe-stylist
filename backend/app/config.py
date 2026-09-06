"""Application configuration.

Loaded from environment / a local .env file (gitignored). Import-safe: no field is
required at import time so tests and tooling run without secrets present. Secrets are
only needed when actually calling Claude.
"""

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Held ONLY on the backend, never shipped to the app.
    anthropic_api_key: str = Field(default="", repr=False)
    # Development-only compatibility credential. Production rejects legacy;
    # bridge requires an explicit expiry. A public iOS binary can't keep this secret.
    device_token: str = Field(default="", repr=False)
    auth_mode: str = "legacy"

    # App Attest identifies one installation without creating a Wardrobe user
    # account.
    # The App ID prefix is usually the Team ID, but must be read from the
    # registered Identifier rather than inferred.
    app_attest_app_id_prefix: str = ""
    app_attest_bundle_id: str = ""
    app_attest_environment: str = "development"
    app_attest_database_path: str = ""
    app_attest_session_secret: str = Field(default="", repr=False)
    app_attest_allowed_validation_categories: str = "3"
    app_attest_allowed_bundle_versions: str = ""
    legacy_bridge_expires_at: str = ""

    app_attest_challenge_ttl_seconds: int = 300
    app_session_ttl_seconds: int = 900
    app_attest_challenge_rate_limit_per_minute: int = 30
    app_attest_registration_rate_limit_per_hour: int = 5
    app_attest_session_rate_limit_per_hour: int = 60
    app_attest_recommend_rate_limit_per_hour: int = 30

    environment: str = "dev"

    # Remote styling is opt-in on the server as well as on the client. Provision
    # the separate accounting store and approve its private limits before enabling.
    ai_styling_enabled: bool = False
    ai_budget_database_path: str = ""
    ai_monthly_unit_limit: int = Field(default=0, ge=0, le=100_000_000, repr=False)
    ai_monthly_request_limit: int = Field(default=0, ge=0, le=100_000, repr=False)
    ai_max_concurrency: int = Field(default=1, ge=1, le=4)
    ai_max_output_tokens: int = Field(default=1024, ge=256, le=2048)


settings = Settings()
