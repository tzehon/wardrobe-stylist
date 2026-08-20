#!/usr/bin/env python3
"""Fail closed when an installable Release archive is not distribution-safe."""

from __future__ import annotations

import ipaddress
import plistlib
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit


class ReleaseConfigurationError(ValueError):
    """Raised when a built public Release configuration is incomplete or unsafe."""


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
_NONPUBLIC_HOST_SUFFIXES = (".home.arpa", ".local")


def _required_string(info: dict[str, Any], key: str) -> str:
    value = info.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ReleaseConfigurationError(f"{key} is missing or empty")
    value = value.strip()
    lowered = value.lower()
    if any(fragment in lowered for fragment in _PLACEHOLDER_FRAGMENTS):
        raise ReleaseConfigurationError(f"{key} contains a placeholder value")
    return value


def _public_https_url(
    info: dict[str, Any],
    key: str,
    *,
    forbid_query_fragment: bool = False,
) -> str:
    raw_value = _required_string(info, key)
    try:
        parts = urlsplit(raw_value)
        host_value = parts.hostname
        # Accessing port performs urllib's range and numeric validation.
        _ = parts.port
    except ValueError as error:
        raise ReleaseConfigurationError(f"{key} must be a well-formed HTTPS URL") from error
    if parts.scheme.lower() != "https" or not host_value:
        raise ReleaseConfigurationError(f"{key} must be an absolute HTTPS URL")
    if parts.username or parts.password:
        raise ReleaseConfigurationError(f"{key} must not contain URL credentials")
    if forbid_query_fragment and ("?" in raw_value or "#" in raw_value):
        raise ReleaseConfigurationError(f"{key} must not contain a query or fragment")
    host = host_value.rstrip(".").lower()
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        address = None
    if address is not None and not address.is_global:
        raise ReleaseConfigurationError(f"{key} must not target a private/local address")
    if (
        host in {"localhost", "localhost.localdomain"}
        or host.endswith(_NONPUBLIC_HOST_SUFFIXES)
        or "." not in host
    ):
        raise ReleaseConfigurationError(f"{key} must use a public hostname")
    return raw_value


def validate(info: dict[str, Any]) -> None:
    """Validate the final built Info.plist, not source configuration files."""
    if info.get("CFBundleDisplayName") != "Wardrobe Stylist":
        raise ReleaseConfigurationError(
            "CFBundleDisplayName must be exactly 'Wardrobe Stylist'"
        )
    if info.get("CFBundleIdentifier") != "com.tth.Wardrobe":
        raise ReleaseConfigurationError(
            "CFBundleIdentifier must be exactly 'com.tth.Wardrobe'"
        )

    # Production talks only to public HTTPS services. Reject the key itself so
    # a locally added development exception cannot survive into an archive,
    # even if it happens to be empty or narrowly scoped today.
    if "NSAppTransportSecurity" in info:
        raise ReleaseConfigurationError(
            "NSAppTransportSecurity must be removed from public Release builds"
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

    if "GIDClientID" in info:
        raise ReleaseConfigurationError("GIDClientID must be absent from this release")
    for url_type in info.get("CFBundleURLTypes", []):
        if not isinstance(url_type, dict):
            raise ReleaseConfigurationError("CFBundleURLTypes is malformed")
        schemes = url_type.get("CFBundleURLSchemes", [])
        if not isinstance(schemes, list):
            raise ReleaseConfigurationError("CFBundleURLSchemes is malformed")
        if any(
            isinstance(scheme, str) and "googleusercontent" in scheme.lower()
            for scheme in schemes
        ):
            raise ReleaseConfigurationError(
                "legacy provider callback URL schemes must be absent from this release"
            )

    if "BGTaskSchedulerPermittedIdentifiers" in info:
        raise ReleaseConfigurationError(
            "BGTaskSchedulerPermittedIdentifiers must be absent from this release"
        )

    _public_https_url(info, "BackendBaseURL", forbid_query_fragment=True)
    _public_https_url(info, "PRIVACY_POLICY_URL")
    _public_https_url(info, "SUPPORT_URL")

    # Absence is intentional. An empty key is still evidence that the obsolete shared-secret
    # architecture remains wired into the target. Public archives authenticate at runtime with
    # a per-installation App Attest key and short-lived backend session instead.
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
