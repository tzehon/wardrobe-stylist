"""Raw ASGI request-size enforcement and cache-safety response headers."""

import asyncio
import json

from app.http_security import MAX_REQUEST_BODY_BYTES, HTTPSecurityMiddleware


def _scope(*, headers=()):
    return {
        "type": "http",
        "asgi": {"version": "3.0"},
        "http_version": "1.1",
        "method": "POST",
        "scheme": "https",
        "path": "/auth/app-attest/register",
        "raw_path": b"/auth/app-attest/register",
        "query_string": b"",
        "root_path": "",
        "headers": list(headers),
        "client": ("192.0.2.10", 12345),
        "server": ("testserver", 443),
    }


def test_declared_oversized_body_is_rejected_before_downstream_app() -> None:
    downstream_called = False
    sent = []

    async def downstream(scope, receive, send):
        del scope, receive, send
        nonlocal downstream_called
        downstream_called = True

    async def receive():
        raise AssertionError("early Content-Length rejection must not read the body")

    async def send(message):
        sent.append(message)

    middleware = HTTPSecurityMiddleware(downstream, max_body_bytes=8)
    asyncio.run(
        middleware(
            _scope(headers=((b"content-length", b"9"),)),
            receive,
            send,
        )
    )

    assert downstream_called is False
    assert sent[0]["status"] == 413
    assert json.loads(sent[1]["body"])["detail"] == "Request body is too large."


def test_chunked_body_is_stopped_at_raw_receive_limit() -> None:
    chunks = iter(
        [
            {"type": "http.request", "body": b"12345", "more_body": True},
            {"type": "http.request", "body": b"6789", "more_body": False},
        ]
    )
    downstream_completed = False
    sent = []

    async def downstream(scope, receive, send):
        del scope, send
        nonlocal downstream_completed
        while True:
            message = await receive()
            if not message.get("more_body", False):
                break
        downstream_completed = True

    async def receive():
        return next(chunks)

    async def send(message):
        sent.append(message)

    middleware = HTTPSecurityMiddleware(downstream, max_body_bytes=8)
    asyncio.run(middleware(_scope(), receive, send))

    assert downstream_completed is False
    assert sent[0]["status"] == 413


def test_all_http_responses_replace_cache_headers_with_no_store() -> None:
    sent = []

    async def downstream(scope, receive, send):
        del scope, receive
        await send(
            {
                "type": "http.response.start",
                "status": 200,
                "headers": [
                    (b"cache-control", b"public, max-age=3600"),
                    (b"content-type", b"application/json"),
                ],
            }
        )
        await send({"type": "http.response.body", "body": b"{}"})

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        sent.append(message)

    asyncio.run(HTTPSecurityMiddleware(downstream)(_scope(), receive, send))

    headers = dict(sent[0]["headers"])
    assert headers[b"cache-control"] == b"no-store"
    assert headers[b"pragma"] == b"no-cache"
    assert headers[b"content-type"] == b"application/json"


def test_unhandled_error_is_redacted_and_returned_with_no_store(caplog) -> None:
    private_error = "PRIVATE_REQUEST_PAYLOAD_IN_EXCEPTION"
    sent = []

    async def downstream(scope, receive, send):
        del scope, receive, send
        raise RuntimeError(private_error)

    async def receive():
        return {"type": "http.request", "body": b"", "more_body": False}

    async def send(message):
        sent.append(message)

    with caplog.at_level("ERROR", logger="app.http_security"):
        asyncio.run(HTTPSecurityMiddleware(downstream)(_scope(), receive, send))

    headers = dict(sent[0]["headers"])
    assert sent[0]["status"] == 500
    assert headers[b"cache-control"] == b"no-store"
    assert headers[b"pragma"] == b"no-cache"
    assert json.loads(sent[1]["body"])["detail"] == "Internal server error."
    log = "\n".join(
        record.getMessage()
        for record in caplog.records
        if record.name == "app.http_security"
    )
    assert "type=RuntimeError" in log
    assert private_error not in log


def test_live_app_rejects_body_over_two_mib_before_request_validation(client) -> None:
    response = client.post(
        "/auth/app-attest/challenge",
        content=b"x" * (MAX_REQUEST_BODY_BYTES + 1),
        headers={"content-type": "application/json"},
    )

    assert response.status_code == 413
    assert response.json()["detail"] == "Request body is too large."
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["pragma"] == "no-cache"
