#!/usr/bin/env python3
"""Fail closed when an installable Release archive is not distribution-safe."""

from __future__ import annotations

import ipaddress
import plistlib
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit


class ReleaseConfigurationError(ValueError):
    """Raised when a built public Release configuration is incomplete or unsafe."""


_CLIENT_ID_PATTERN = re.compile(
    r"^(?P<prefix>[0-9]+-[A-Za-z0-9_-]+)\.apps\.googleusercontent\.com$"
)
_PLACEHOLDER_FRAGMENTS = (
    "example.com",
    "example.net",
    "example.org",
    "localhost",
    ".invalid",
    ".test",
    "your-domain",
    "yourdomain",
    "placeholder",
    "replace-me",
    "paste-",
    "$(",
)


def _required_string(info: dict[str, Any], key: str) -> str:
    value = info.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ReleaseConfigurationError(f"{key} is missing or empty")
    value = value.strip()
    lowered = value.lower()
    if any(fragment in lowered for fragment in _PLACEHOLDER_FRAGMENTS):
        raise ReleaseConfigurationError(f"{key} contains a placeholder value")
    return value


def _public_https_url(info: dict[str, Any], key: str) -> str:
    raw_value = _required_string(info, key)
    parts = urlsplit(raw_value)
    if parts.scheme.lower() != "https" or not parts.hostname:
        raise ReleaseConfigurationError(f"{key} must be an absolute HTTPS URL")
    if parts.username or parts.password:
        raise ReleaseConfigurationError(f"{key} must not contain URL credentials")
    host = parts.hostname.rstrip(".").lower()
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        address = None
    if address is not None and not address.is_global:
        raise ReleaseConfigurationError(f"{key} must not target a private/local address")
    if host in {"localhost", "localhost.localdomain"} or "." not in host:
        raise ReleaseConfigurationError(f"{key} must use a public hostname")
    return raw_value


def _first_url_scheme(info: dict[str, Any]) -> str:
    url_types = info.get("CFBundleURLTypes")
    if not isinstance(url_types, list) or not url_types:
        raise ReleaseConfigurationError("CFBundleURLTypes is missing")
    first = url_types[0]
    if not isinstance(first, dict):
        raise ReleaseConfigurationError("CFBundleURLTypes is malformed")
    schemes = first.get("CFBundleURLSchemes")
    if not isinstance(schemes, list) or len(schemes) != 1:
        raise ReleaseConfigurationError("exactly one Google callback URL scheme is required")
    scheme = schemes[0]
    if not isinstance(scheme, str) or not scheme.strip():
        raise ReleaseConfigurationError("Google callback URL scheme is missing")
    return scheme.strip()


def validate(info: dict[str, Any]) -> None:
    """Validate the final built Info.plist, not source configuration files."""
    if info.get("CFBundleDisplayName") != "Wardrobe Stylist":
        raise ReleaseConfigurationError(
            "CFBundleDisplayName must be exactly 'Wardrobe Stylist'"
        )

    launch_screen = info.get("UILaunchScreen")
    if not isinstance(launch_screen, dict):
        raise ReleaseConfigurationError("UILaunchScreen must be configured")
    if launch_screen.get("UIColorName") != "LaunchBackground":
        raise ReleaseConfigurationError(
            "UILaunchScreen must use the branded LaunchBackground color"
        )
    if launch_screen.get("UIImageName") != "LaunchMark":
        raise ReleaseConfigurationError(
            "UILaunchScreen must use the branded LaunchMark image"
        )
    if launch_screen.get("UIImageRespectsSafeAreaInsets") is not True:
        raise ReleaseConfigurationError(
            "UILaunchScreen must keep LaunchMark inside safe-area insets"
        )

    client_id = _required_string(info, "GIDClientID")
    match = _CLIENT_ID_PATTERN.fullmatch(client_id)
    if match is None:
        raise ReleaseConfigurationError("GIDClientID is not a production Google iOS client ID")
    expected_scheme = f"com.googleusercontent.apps.{match.group('prefix')}"
    if _first_url_scheme(info) != expected_scheme:
        raise ReleaseConfigurationError(
            "Google callback URL scheme does not match the reversed GIDClientID"
        )

    _public_https_url(info, "BackendBaseURL")
    _public_https_url(info, "PRIVACY_POLICY_URL")
    _public_https_url(info, "SUPPORT_URL")

    # Absence is intentional. An empty key is still evidence that the obsolete shared-secret
    # architecture remains wired into the target, so public archives stay blocked until the
    # per-user backend identity migration in the GCP production sequence is complete.
    if "BackendDeviceToken" in info:
        raise ReleaseConfigurationError(
            "BackendDeviceToken must be removed from the public app and Info.plist"
        )


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} BUILT_INFO_PLIST", file=sys.stderr)
        return 2
    path = Path(argv[1])
    try:
        with path.open("rb") as handle:
            info = plistlib.load(handle)
        if not isinstance(info, dict):
            raise ReleaseConfigurationError("Info.plist root must be a dictionary")
        validate(info)
    except (OSError, plistlib.InvalidFileException, ReleaseConfigurationError) as error:
        print(f"Public Release configuration failed: {error}", file=sys.stderr)
        return 1
    print("Public Release configuration verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
