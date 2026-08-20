#!/usr/bin/env python3

from __future__ import annotations

import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path
from typing import Any


SCRIPT = Path(__file__).parents[1] / "validate_public_release.py"
SPEC = importlib.util.spec_from_file_location("validate_public_release", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def valid_info() -> dict[str, Any]:
    return {
        "CFBundleDisplayName": "Wardrobe Stylist",
        "CFBundleIdentifier": "com.tth.Wardrobe",
        "UILaunchScreen": {
            "UIColorName": "LaunchBackground",
            "UIImageName": "LaunchMark",
            "UIImageRespectsSafeAreaInsets": True,
        },
        "BackendBaseURL": "https://api.wardrobestylist.app",
        "PRIVACY_POLICY_URL": "https://wardrobestylist.app/privacy",
        "SUPPORT_URL": "https://wardrobestylist.app/support",
    }


class PublicReleaseValidationTests(unittest.TestCase):
    def test_accepts_complete_safe_configuration(self) -> None:
        MODULE.validate(valid_info())

    def test_rejects_missing_policy_url(self) -> None:
        info = valid_info()
        del info["PRIVACY_POLICY_URL"]
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "PRIVACY_POLICY_URL"):
            MODULE.validate(info)

    def test_rejects_empty_launch_treatment(self) -> None:
        info = valid_info()
        info["UILaunchScreen"] = {}
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "LaunchBackground"):
            MODULE.validate(info)

    def test_rejects_placeholder_support_url(self) -> None:
        info = valid_info()
        info["SUPPORT_URL"] = "https://example.com/support"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "placeholder"):
            MODULE.validate(info)

    def test_rejects_non_https_backend(self) -> None:
        info = valid_info()
        info["BackendBaseURL"] = "http://api.wardrobestylist.app"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "HTTPS"):
            MODULE.validate(info)

    def test_rejects_backend_query(self) -> None:
        info = valid_info()
        info["BackendBaseURL"] = "https://api.wardrobestylist.app?destination=elsewhere"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "query or fragment"):
            MODULE.validate(info)

    def test_rejects_backend_fragment(self) -> None:
        info = valid_info()
        info["BackendBaseURL"] = "https://api.wardrobestylist.app#alternate"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "query or fragment"):
            MODULE.validate(info)

    def test_rejects_malformed_backend_port_without_leaking_a_value_error(self) -> None:
        info = valid_info()
        info["BackendBaseURL"] = "https://api.wardrobestylist.app:99999"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "well-formed"):
            MODULE.validate(info)

    def test_rejects_wrong_bundle_identifier(self) -> None:
        info = valid_info()
        info["CFBundleIdentifier"] = "com.example.Wardrobe"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "CFBundleIdentifier"):
            MODULE.validate(info)

    def test_rejects_app_transport_security_key_even_when_empty(self) -> None:
        info = valid_info()
        info["NSAppTransportSecurity"] = {}
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "NSAppTransportSecurity"):
            MODULE.validate(info)

    def test_rejects_private_backend_address(self) -> None:
        info = valid_info()
        info["BackendBaseURL"] = "https://192.168.1.10"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "private/local"):
            MODULE.validate(info)

    def test_rejects_special_use_local_backend_hostname(self) -> None:
        info = valid_info()
        info["BackendBaseURL"] = "https://wardrobe.home.arpa"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "public hostname"):
            MODULE.validate(info)

    def test_rejects_legacy_client_identifier(self) -> None:
        info = valid_info()
        info["GIDClientID"] = "legacy-client"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "must be absent"):
            MODULE.validate(info)

    def test_rejects_legacy_callback_scheme(self) -> None:
        info = valid_info()
        info["CFBundleURLTypes"] = [
            {"CFBundleURLSchemes": ["com.googleusercontent.apps.legacy-client"]}
        ]
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "must be absent"):
            MODULE.validate(info)

    def test_rejects_background_task_identifiers(self) -> None:
        info = valid_info()
        info["BGTaskSchedulerPermittedIdentifiers"] = ["com.tth.Wardrobe.legacySync"]
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "must be absent"):
            MODULE.validate(info)

    def test_rejects_shared_bearer_even_when_empty(self) -> None:
        info = valid_info()
        info["BackendDeviceToken"] = ""
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "must be removed"):
            MODULE.validate(info)

    def test_cli_reads_binary_plist(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Info.plist"
            with path.open("wb") as handle:
                plistlib.dump(valid_info(), handle, fmt=plistlib.FMT_BINARY)
            self.assertEqual(MODULE.main([str(SCRIPT), str(path)]), 0)


if __name__ == "__main__":
    unittest.main()
