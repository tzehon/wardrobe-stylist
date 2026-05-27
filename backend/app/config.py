"""Application configuration.

Loaded from environment / a local .env file (gitignored). Import-safe: no field is
required at import time so tests and tooling run without secrets present. Secrets are
only needed when actually calling Claude.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Held ONLY on the backend, never shipped to the app.
    anthropic_api_key: str = ""
    # Shared secret the single iOS client sends as a Bearer token.
    device_token: str = ""
    environment: str = "dev"


settings = Settings()
