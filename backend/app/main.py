"""FastAPI entrypoint.

The backend exists solely to keep the Anthropic API key off the device and to
let us iterate on prompts/agent logic without app rebuilds. It never persists
email or wardrobe content. It does durably retain the minimum App Attest
authentication/security metadata required for replay-safe anonymous sessions.
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.auth.runtime import initialize_auth_runtime
from app.config import settings
from app.http_security import MAX_REQUEST_BODY_BYTES, HTTPSecurityMiddleware
from app.routes import auth, extract, recommend


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    initialize_auth_runtime()
    yield


app = FastAPI(title="Wardrobe Stylist API", version="0.1.0", lifespan=lifespan)
app.add_middleware(
    HTTPSecurityMiddleware,
    max_body_bytes=MAX_REQUEST_BODY_BYTES,
)
app.include_router(auth.router)
app.include_router(extract.router)
app.include_router(recommend.router)


@app.get("/health")
async def health() -> dict[str, str]:
    """Liveness check (no auth, no secrets required)."""
    return {"status": "ok", "environment": settings.environment}
