"""FastAPI entrypoint.

The backend exists solely to keep the Anthropic API key off the device and to let us
iterate on prompts/agent logic without app rebuilds. It is stateless and must never
persist email content. Routes for /extract, /categorize, /recommend are added in later
phases.
"""

from fastapi import FastAPI

from app.config import settings

app = FastAPI(title="Wardrobe Stylist API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness check (no auth, no secrets required)."""
    return {"status": "ok", "environment": settings.environment}
