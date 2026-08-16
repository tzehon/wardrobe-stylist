"""Resolve a bounded rate-limit subject without trusting proxy chains."""

from ipaddress import ip_address

from fastapi import Request


def request_client_ip(request: Request, *, production: bool) -> str:
    if production:
        # Fly Proxy adds Fly-Client-IP as the address it accepted. We trust it
        # only in the Fly production deployment and deliberately never parse
        # spoofable X-Forwarded-For chains here.
        # https://fly.io/docs/networking/request-headers/#fly-client-ip
        candidate = request.headers.get("Fly-Client-IP")
        if candidate is not None and "," not in candidate:
            try:
                return str(ip_address(candidate.strip()))
            except ValueError:
                pass
    return request.client.host if request.client is not None else "unknown"
