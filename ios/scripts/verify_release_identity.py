#!/usr/bin/env python3
"""Cross-check a signed device app against its embedded provisioning profile."""

from __future__ import annotations

import plistlib
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

EXPECTED_BUNDLE_ID = "com.tth.Wardrobe"
APP_ATTEST_ENTITLEMENT = "com.apple.developer.devicecheck.appattest-environment"


class ReleaseIdentityError(ValueError):
    """Raised when archive identity or signing facts do not agree."""


def _required_string(values: dict[str, Any], key: str, *, source: str) -> str:
    value = values.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ReleaseIdentityError(f"{source} is missing {key}")
    return value.strip()


def _single_string(values: dict[str, Any], key: str, *, source: str) -> str:
    value = values.get(key)
    if (
        not isinstance(value, list)
        or len(value) != 1
        or not isinstance(value[0], str)
        or not value[0].strip()
    ):
        raise ReleaseIdentityError(f"{source} must contain exactly one {key}")
    return value[0].strip()


def _allowed_strings(values: dict[str, Any], key: str, *, source: str) -> set[str]:
    value = values.get(key)
    allowed_values = {"development", "production"}
    if isinstance(value, str) and value in allowed_values:
        return {value}
    if (
        isinstance(value, list)
        and value
        and all(isinstance(item, str) and item in allowed_values for item in value)
    ):
        return set(value)
    raise ReleaseIdentityError(f"{source} has invalid {key}")


def _profile_expiration(
    profile: dict[str, Any],
    *,
    now: datetime | None = None,
) -> None:
    expiration = profile.get("ExpirationDate")
    if not isinstance(expiration, datetime):
        raise ReleaseIdentityError(
            "embedded provisioning profile is missing a valid ExpirationDate"
        )

    # Provisioning-profile plists encode UTC dates without an explicit timezone.
    expiration_utc = (
        expiration.replace(tzinfo=timezone.utc)
        if expiration.tzinfo is None
        else expiration.astimezone(timezone.utc)
    )
    current = now or datetime.now(timezone.utc)
    current_utc = (
        current.replace(tzinfo=timezone.utc)
        if current.tzinfo is None
        else current.astimezone(timezone.utc)
    )
    if expiration_utc <= current_utc:
        raise ReleaseIdentityError("embedded provisioning profile has expired")


def _verify_signing_certificate(
    profile: dict[str, Any], signing_certificate: bytes
) -> None:
    if not signing_certificate:
        raise ReleaseIdentityError("signed app leaf certificate is empty")
    developer_certificates = profile.get("DeveloperCertificates")
    if (
        not isinstance(developer_certificates, list)
        or not developer_certificates
        or any(
            not isinstance(certificate, bytes) or not certificate
            for certificate in developer_certificates
        )
    ):
        raise ReleaseIdentityError(
            "embedded provisioning profile has invalid DeveloperCertificates"
        )
    if signing_certificate not in developer_certificates:
        raise ReleaseIdentityError(
            "signed app leaf certificate is not authorized by the embedded provisioning profile"
        )


def validate_signed_identity(
    info: dict[str, Any],
    signed_entitlements: dict[str, Any],
    profile: dict[str, Any],
    signing_certificate: bytes,
    *,
    now: datetime | None = None,
) -> None:
    """Require the bundle, signed entitlements, and profile to describe one App ID."""
    bundle_id = _required_string(info, "CFBundleIdentifier", source="built Info.plist")
    if bundle_id != EXPECTED_BUNDLE_ID:
        raise ReleaseIdentityError(
            f"built bundle identifier must be exactly {EXPECTED_BUNDLE_ID}"
        )

    profile_entitlements = profile.get("Entitlements")
    if not isinstance(profile_entitlements, dict):
        raise ReleaseIdentityError(
            "embedded provisioning profile has no Entitlements dictionary"
        )
    if (
        profile_entitlements.get("get-task-allow") is not False
        or profile_entitlements.get("beta-reports-active") is not True
        or "ProvisionedDevices" in profile
        or "ProvisionsAllDevices" in profile
    ):
        raise ReleaseIdentityError(
            "embedded provisioning profile must be for App Store distribution"
        )
    if (
        "get-task-allow" in signed_entitlements
        and signed_entitlements["get-task-allow"] is not False
    ):
        raise ReleaseIdentityError(
            "signed app get-task-allow must be absent or exactly false"
        )

    _profile_expiration(profile, now=now)
    _verify_signing_certificate(profile, signing_certificate)

    app_id_prefix = _single_string(
        profile,
        "ApplicationIdentifierPrefix",
        source="embedded provisioning profile",
    ).removesuffix(".")
    team_id = _single_string(
        profile,
        "TeamIdentifier",
        source="embedded provisioning profile",
    )
    expected_application_id = f"{app_id_prefix}.{bundle_id}"

    signed_application_id = _required_string(
        signed_entitlements,
        "application-identifier",
        source="signed app entitlements",
    )
    profile_application_id = _required_string(
        profile_entitlements,
        "application-identifier",
        source="embedded profile entitlements",
    )
    if signed_application_id != expected_application_id:
        raise ReleaseIdentityError(
            "signed app application-identifier does not match the profile App ID prefix and bundle"
        )
    if profile_application_id != expected_application_id:
        raise ReleaseIdentityError(
            "embedded profile application-identifier does not match its App ID prefix and bundle"
        )

    signed_team_id = _required_string(
        signed_entitlements,
        "com.apple.developer.team-identifier",
        source="signed app entitlements",
    )
    profile_team_id = _required_string(
        profile_entitlements,
        "com.apple.developer.team-identifier",
        source="embedded profile entitlements",
    )
    if signed_team_id != team_id or profile_team_id != team_id:
        raise ReleaseIdentityError(
            "signed app and embedded profile TeamIdentifier values do not match"
        )

    signed_environment = signed_entitlements.get(APP_ATTEST_ENTITLEMENT)
    profile_environments = _allowed_strings(
        profile_entitlements,
        APP_ATTEST_ENTITLEMENT,
        source="embedded profile entitlements",
    )
    if signed_environment != "production" or "production" not in profile_environments:
        raise ReleaseIdentityError(
            "signed app and embedded profile must both grant production App Attest"
        )


def _load_plist(path: Path) -> dict[str, Any]:
    with path.open("rb") as handle:
        value = plistlib.load(handle)
    if not isinstance(value, dict):
        raise ReleaseIdentityError(f"{path.name} root must be a dictionary")
    return value


def main(argv: list[str]) -> int:
    if len(argv) != 5:
        print(
            f"usage: {argv[0]} BUILT_INFO_PLIST SIGNED_ENTITLEMENTS_PLIST "
            "PROFILE_PLIST SIGNING_LEAF_CERTIFICATE_DER",
            file=sys.stderr,
        )
        return 2
    try:
        validate_signed_identity(
            *(_load_plist(Path(value)) for value in argv[1:4]),
            Path(argv[4]).read_bytes(),
        )
    except (OSError, plistlib.InvalidFileException, ReleaseIdentityError) as error:
        print(f"Release identity verification failed: {error}", file=sys.stderr)
        return 1
    print("Release identity and embedded provisioning profile verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
