"""HTTP-level safety controls applied before FastAPI buffers request bodies."""

from __future__ import annotations

import json
import logging

from starlette.types import ASGIApp, Message, Receive, Scope, Send

MAX_REQUEST_BODY_BYTES = 2 * 1024 * 1024
logger = logging.getLogger(__name__)

_CACHE_HEADER_NAMES = {b"cache-control", b"pragma"}
_NO_STORE_HEADERS = [
    (b"cache-control", b"no-store"),
    (b"pragma", b"no-cache"),
]


class _RequestBodyTooLarge(Exception):
    pass


class HTTPSecurityMiddleware:
    """Bound request bytes at the ASGI receive layer and disable response caching."""

    def __init__(self, app: ASGIApp, *, max_body_bytes: int = MAX_REQUEST_BODY_BYTES) -> None:
        if max_body_bytes <= 0:
            raise ValueError("max_body_bytes must be positive")
        self.app = app
        self.max_body_bytes = max_body_bytes

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        declared_length = _declared_content_length(scope)
        if declared_length is not None and declared_length > self.max_body_bytes:
            await _send_too_large(send)
            return

        received_bytes = 0
        response_started = False

        async def limited_receive() -> Message:
            nonlocal received_bytes
            message = await receive()
            if message["type"] == "http.request":
                received_bytes += len(message.get("body", b""))
                if received_bytes > self.max_body_bytes:
                    raise _RequestBodyTooLarge
            return message

        async def no_store_send(message: Message) -> None:
            nonlocal response_started
            if message["type"] == "http.response.start":
                response_started = True
                headers = [
                    (name, value)
                    for name, value in message.get("headers", [])
                    if name.lower() not in _CACHE_HEADER_NAMES
                ]
                message = {**message, "headers": headers + _NO_STORE_HEADERS}
            await send(message)

        try:
            await self.app(scope, limited_receive, no_store_send)
        except _RequestBodyTooLarge:
            # FastAPI reads request bodies before entering a route, so a normal
            # oversized API request has not begun a response. Preserve ASGI
            # correctness if a future streaming endpoint changes that ordering.
            if response_started:
                raise
            await _send_too_large(send)
        except Exception as exc:
            # Starlette's outer ServerErrorMiddleware otherwise creates the 500
            # outside user middleware, bypassing the no-store headers, and logs
            # exception text that may contain caller payloads. No endpoint in
            # this API streams a response, so failures should occur pre-start.
            if response_started:
                raise
            logger.error("unhandled_api_error type=%s", type(exc).__name__)
            await _send_internal_error(send)


def _declared_content_length(scope: Scope) -> int | None:
    raw_values = [
        value
        for name, value in scope.get("headers", [])
        if name.lower() == b"content-length"
    ]
    if len(raw_values) != 1:
        return None
    try:
        value = int(raw_values[0].decode("ascii"))
    except (UnicodeDecodeError, ValueError):
        return None
    return value if value >= 0 else None


async def _send_too_large(send: Send) -> None:
    await _send_json_error(
        send,
        status_code=413,
        detail="Request body is too large.",
        close_connection=True,
    )


async def _send_internal_error(send: Send) -> None:
    await _send_json_error(
        send,
        status_code=500,
        detail="Internal server error.",
    )


async def _send_json_error(
    send: Send,
    *,
    status_code: int,
    detail: str,
    close_connection: bool = False,
) -> None:
    body = json.dumps(
        {"detail": detail},
        separators=(",", ":"),
    ).encode("utf-8")
    headers = [
        (b"content-type", b"application/json"),
        (b"content-length", str(len(body)).encode("ascii")),
        *_NO_STORE_HEADERS,
    ]
    if close_connection:
        headers.append((b"connection", b"close"))
    await send(
        {
            "type": "http.response.start",
            "status": status_code,
            "headers": headers,
        }
    )
    await send({"type": "http.response.body", "body": body})
