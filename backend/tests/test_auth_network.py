"""Trusted client-IP selection for Fly-backed rate limits."""

from fastapi import Request

from app.auth.network import request_client_ip


def test_production_prefers_valid_single_fly_client_ip() -> None:
    request = _request(
        headers=[(b"fly-client-ip", b"2001:0db8::1")],
        direct_ip="fdaa::3",
    )
    assert request_client_ip(request, production=True) == "2001:db8::1"


def test_production_rejects_list_or_invalid_fly_client_ip() -> None:
    for value in (b"192.0.2.1, 192.0.2.2", b"not-an-ip"):
        request = _request(headers=[(b"fly-client-ip", value)], direct_ip="fdaa::3")
        assert request_client_ip(request, production=True) == "fdaa::3"


def test_nonproduction_ignores_fly_and_forwarded_headers() -> None:
    request = _request(
        headers=[
            (b"fly-client-ip", b"192.0.2.1"),
            (b"x-forwarded-for", b"198.51.100.9"),
        ],
        direct_ip="127.0.0.1",
    )
    assert request_client_ip(request, production=False) == "127.0.0.1"


def test_production_never_falls_back_to_x_forwarded_for() -> None:
    request = _request(
        headers=[(b"x-forwarded-for", b"198.51.100.9")],
        direct_ip="fdaa::4",
    )
    assert request_client_ip(request, production=True) == "fdaa::4"


def _request(*, headers: list[tuple[bytes, bytes]], direct_ip: str) -> Request:
    return Request(
        {
            "type": "http",
            "http_version": "1.1",
            "method": "POST",
            "scheme": "https",
            "path": "/auth/app-attest/challenge",
            "raw_path": b"/auth/app-attest/challenge",
            "query_string": b"",
            "headers": headers,
            "client": (direct_ip, 12345),
            "server": ("testserver", 443),
        }
    )
