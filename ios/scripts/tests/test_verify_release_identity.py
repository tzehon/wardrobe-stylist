#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import plistlib
import tempfile
import unittest
from datetime import datetime, timezone
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
SIGNING_CERTIFICATE = b"matching-signing-certificate-der"
NOW = datetime(2026, 8, 21, 12, 0, tzinfo=timezone.utc)


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
        "DeveloperCertificates": [SIGNING_CERTIFICATE],
        "ExpirationDate": datetime(2027, 8, 21, 12, 0),
        "Entitlements": {
            "application-identifier": APPLICATION_ID,
            "com.apple.developer.team-identifier": TEAM_ID,
            APP_ATTEST: ["development", "production"],
            "beta-reports-active": True,
            "get-task-allow": False,
        },
    }
    return info, signed_entitlements, profile


def validate(
    info: dict[str, Any],
    entitlements: dict[str, Any],
    profile: dict[str, Any],
    certificate: bytes = SIGNING_CERTIFICATE,
) -> None:
    MODULE.validate_signed_identity(
        info,
        entitlements,
        profile,
        certificate,
        now=NOW,
    )


class ReleaseIdentityTests(unittest.TestCase):
    def test_accepts_matching_profile_without_assuming_prefix_equals_team(self) -> None:
        validate(*valid_identity())

    def test_accepts_legacy_scalar_production_app_attest_profile(self) -> None:
        info, entitlements, profile = valid_identity()
        profile["Entitlements"][APP_ATTEST] = "production"
        validate(info, entitlements, profile)

    def test_accepts_absent_or_false_signed_get_task_allow(self) -> None:
        for value in (None, False):
            with self.subTest(value=value):
                info, entitlements, profile = valid_identity()
                if value is not None:
                    entitlements["get-task-allow"] = value
                validate(info, entitlements, profile)

    def test_accepts_signing_leaf_present_later_in_profile_certificate_list(
        self,
    ) -> None:
        info, entitlements, profile = valid_identity()
        profile["DeveloperCertificates"] = [b"another-certificate", SIGNING_CERTIFICATE]
        validate(info, entitlements, profile)

    def test_rejects_wrong_bundle_identifier(self) -> None:
        info, entitlements, profile = valid_identity()
        info["CFBundleIdentifier"] = "com.example.Wardrobe"
        with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "bundle identifier"):
            validate(info, entitlements, profile)

    def test_rejects_signed_app_with_different_app_id_prefix(self) -> None:
        info, entitlements, profile = valid_identity()
        entitlements["application-identifier"] = f"WRONG12345.{BUNDLE_ID}"
        with self.assertRaisesRegex(
            MODULE.ReleaseIdentityError, "signed app application-identifier"
        ):
            validate(info, entitlements, profile)

    def test_rejects_profile_entitlement_for_different_bundle(self) -> None:
        info, entitlements, profile = valid_identity()
        profile["Entitlements"]["application-identifier"] = (
            f"{APP_ID_PREFIX}.com.tth.AnotherApp"
        )
        with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "embedded profile"):
            validate(info, entitlements, profile)

    def test_rejects_development_provisioning_profile(self) -> None:
        info, entitlements, profile = valid_identity()
        profile["Entitlements"]["get-task-allow"] = True
        with self.assertRaisesRegex(
            MODULE.ReleaseIdentityError, "App Store distribution"
        ):
            validate(info, entitlements, profile)

    def test_rejects_profile_without_beta_reporting(self) -> None:
        for value in (None, False):
            with self.subTest(value=value):
                info, entitlements, profile = valid_identity()
                if value is None:
                    del profile["Entitlements"]["beta-reports-active"]
                else:
                    profile["Entitlements"]["beta-reports-active"] = value
                with self.assertRaisesRegex(
                    MODULE.ReleaseIdentityError, "App Store distribution"
                ):
                    validate(info, entitlements, profile)

    def test_rejects_device_scoped_distribution_profile(self) -> None:
        for devices in ([], ["device-identifier"]):
            with self.subTest(devices=devices):
                info, entitlements, profile = valid_identity()
                profile["ProvisionedDevices"] = devices
                with self.assertRaisesRegex(
                    MODULE.ReleaseIdentityError, "App Store distribution"
                ):
                    validate(info, entitlements, profile)

    def test_rejects_all_devices_distribution_profile(self) -> None:
        for provision_all in (False, True, 1, "true"):
            with self.subTest(provision_all=provision_all):
                info, entitlements, profile = valid_identity()
                profile["ProvisionsAllDevices"] = provision_all
                with self.assertRaisesRegex(
                    MODULE.ReleaseIdentityError, "App Store distribution"
                ):
                    validate(info, entitlements, profile)

    def test_rejects_development_app_attest_profile(self) -> None:
        info, entitlements, profile = valid_identity()
        profile["Entitlements"][APP_ATTEST] = ["development"]
        with self.assertRaisesRegex(
            MODULE.ReleaseIdentityError, "production App Attest"
        ):
            validate(info, entitlements, profile)

    def test_rejects_development_signed_app_when_profile_allows_production(
        self,
    ) -> None:
        for value in (None, "development", " production ", ["production"]):
            with self.subTest(value=value):
                info, entitlements, profile = valid_identity()
                if value is None:
                    del entitlements[APP_ATTEST]
                else:
                    entitlements[APP_ATTEST] = value
                with self.assertRaisesRegex(
                    MODULE.ReleaseIdentityError, "production App Attest"
                ):
                    validate(info, entitlements, profile)

    def test_rejects_malformed_app_attest_profile_allowlist(self) -> None:
        for value in (
            [],
            " production ",
            ["production", 1],
            ["production", "bogus"],
        ):
            with self.subTest(value=value):
                info, entitlements, profile = valid_identity()
                profile["Entitlements"][APP_ATTEST] = value
                with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "invalid"):
                    validate(info, entitlements, profile)

    def test_rejects_present_non_false_signed_get_task_allow(self) -> None:
        for value in (True, 0, "false", None):
            with self.subTest(value=value):
                info, entitlements, profile = valid_identity()
                entitlements["get-task-allow"] = value
                with self.assertRaisesRegex(
                    MODULE.ReleaseIdentityError, "signed app get-task-allow"
                ):
                    validate(info, entitlements, profile)

    def test_rejects_expired_profile(self) -> None:
        info, entitlements, profile = valid_identity()
        profile["ExpirationDate"] = NOW
        with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "expired"):
            validate(info, entitlements, profile)

    def test_rejects_missing_or_malformed_profile_expiration(self) -> None:
        for value in (None, "2027-08-21"):
            with self.subTest(value=value):
                info, entitlements, profile = valid_identity()
                if value is None:
                    del profile["ExpirationDate"]
                else:
                    profile["ExpirationDate"] = value
                with self.assertRaisesRegex(
                    MODULE.ReleaseIdentityError, "ExpirationDate"
                ):
                    validate(info, entitlements, profile)

    def test_rejects_signing_leaf_not_in_profile(self) -> None:
        info, entitlements, profile = valid_identity()
        with self.assertRaisesRegex(MODULE.ReleaseIdentityError, "not authorized"):
            validate(info, entitlements, profile, b"different-signing-certificate")

    def test_rejects_missing_or_malformed_profile_certificates(self) -> None:
        for value in (None, [], [b""], ["not-der-bytes"]):
            with self.subTest(value=value):
                info, entitlements, profile = valid_identity()
                if value is None:
                    del profile["DeveloperCertificates"]
                else:
                    profile["DeveloperCertificates"] = value
                with self.assertRaisesRegex(
                    MODULE.ReleaseIdentityError, "DeveloperCertificates"
                ):
                    validate(info, entitlements, profile)

    def test_cli_compares_signing_leaf_certificate(self) -> None:
        info, entitlements, profile = valid_identity()
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = [
                root / name
                for name in ("Info.plist", "Entitlements.plist", "Profile.plist")
            ]
            for path, value in zip(paths, (info, entitlements, profile)):
                with path.open("wb") as handle:
                    plistlib.dump(value, handle)
            certificate_path = root / "signing-certificate.der"
            certificate_path.write_bytes(SIGNING_CERTIFICATE)

            self.assertEqual(
                MODULE.main(
                    [str(SCRIPT), *(str(path) for path in paths), str(certificate_path)]
                ),
                0,
            )


if __name__ == "__main__":
    unittest.main()
