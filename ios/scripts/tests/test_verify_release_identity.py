#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path
from typing import Any


SCRIPT = Path(__file__).parents[1] / "verify_release_identity.py"
SPEC = importlib.util.spec_from_file_location("verify_release_identity", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)

APP_ID_PREFIX = "LEGACY1234"
TEAM_ID = "CURRENT1234"
BUNDLE_ID = "com.tth.Wardrobe"
APPLICATION_ID = f"{APP_ID_PREFIX}.{BUNDLE_ID}"
APP_ATTEST = "com.apple.developer.devicecheck.appattest-environment"


def valid_identity() -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    info = {"CFBundleIdentifier": BUNDLE_ID}
    signed_entitlements = {
        "application-identifier": APPLICATION_ID,
        "com.apple.developer.team-identifier": TEAM_ID,
        APP_ATTEST: "production",
    }
    profile = {
        "ApplicationIdentifierPrefix": [APP_ID_PREFIX],
        "TeamIdentifier": [TEAM_ID],
        "Entitlements": {
            "application-identifier": APPLICATION_ID,
            "com.apple.developer.team-identifier": TEAM_ID,
            APP_ATTEST: "production",
        },
    }
    return info, signed_entitlements, profile


class ReleaseIdentityTests(unittest.TestCase):
    def test_accepts_matching_profile_without_assuming_prefix_equals_team(self) -> None:
        MODULE.validate_signed_identity(*valid_identity())

    def test_rejects_wrong_bundle_identifier(self) -> None:
        info, entitlements, profile = valid_identity()
        info["CFBundleIdentifier"] = "com.example.Wardrobe"
        with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "bundle identifier"):
            MODULE.validate_signed_identity(info, entitlements, profile)

    def test_rejects_signed_app_with_different_app_id_prefix(self) -> None:
        info, entitlements, profile = valid_identity()
        entitlements["application-identifier"] = f"WRONG12345.{BUNDLE_ID}"
        with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "signed app application-identifier"):
            MODULE.validate_signed_identity(info, entitlements, profile)

    def test_rejects_profile_entitlement_for_different_bundle(self) -> None:
        info, entitlements, profile = valid_identity()
        profile["Entitlements"]["application-identifier"] = (
            f"{APP_ID_PREFIX}.com.tth.AnotherApp"
        )
        with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "embedded profile"):
            MODULE.validate_signed_identity(info, entitlements, profile)

    def test_rejects_development_app_attest_profile(self) -> None:
        info, entitlements, profile = valid_identity()
        profile["Entitlements"][APP_ATTEST] = "development"
        with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "production App Attest"):
            MODULE.validate_signed_identity(info, entitlements, profile)


if __name__ == "__main__":
    unittest.main()
