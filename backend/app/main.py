"""FastAPI entrypoint.

The backend exists solely to keep the Anthropic API key off the device and to
let us iterate on prompts/agent logic without app rebuilds. It never persists
wardrobe content. It does durably retain the minimum App Attest
authentication/security metadata required for replay-safe anonymous sessions.
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.auth.runtime import initialize_auth_runtime
from app.config import settings
from app.http_security import MAX_REQUEST_BODY_BYTES, HTTPSecurityMiddleware
from app.routes import auth, recommend


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    auth_service = initialize_auth_runtime()
    auth_service.start_maintenance()
    try:
        yield
    finally:
        await auth_service.stop_maintenance()


app = FastAPI(title="Wardrobe Stylist API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    HTTPSecurityMiddleware,
    max_body_bytes=MAX_REQUEST_BODY_BYTES,
)
app.include_router(auth.router)
app.include_router(recommend.router)


@app.get("/health")
async def health() -> dict[str, str]:
    """Liveness check (no auth, no secrets required)."""
    return {"status": "ok", "environment": settings.environment}
