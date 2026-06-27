"""FastAPI entrypoint.

The backend exists solely to keep the Anthropic API key off the device and to
let us iterate on prompts/agent logic without app rebuilds. It is stateless and
never persists email content. Routes are added per phase.
"""

from fastapi import FastAPI

from app.config import settings
from app.routes import extract, recommend

app = FastAPI(title="Wardrobe Stylist API", version="0.1.0")
app.include_router(extract.router)
app.include_router(recommend.router)


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness check (no auth, no secrets required)."""
    return {"status": "ok", "environment": settings.environment}
