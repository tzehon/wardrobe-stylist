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
    client_id = "123456789012-realclient.apps.googleusercontent.com"
    return {
        "CFBundleDisplayName": "Wardrobe Stylist",
        "GIDClientID": client_id,
        "CFBundleURLTypes": [
            {
                "CFBundleURLSchemes": [
                    "com.googleusercontent.apps.123456789012-realclient"
                ]
            }
        ],
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

    def test_rejects_private_backend_address(self) -> None:
        info = valid_info()
        info["BackendBaseURL"] = "https://192.168.1.10"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "private/local"):
            MODULE.validate(info)

    def test_rejects_mismatched_callback_scheme(self) -> None:
        info = valid_info()
        info["CFBundleURLTypes"][0]["CFBundleURLSchemes"] = [
            "com.googleusercontent.apps.another-client"
        ]
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "does not match"):
            MODULE.validate(info)

    def test_rejects_unresolved_client_id(self) -> None:
        info = valid_info()
        info["GIDClientID"] = "$(GOOGLE_CLIENT_ID)"
        with self.assertRaisesRegex(MODULE.ReleaseConfigurationError, "placeholder"):
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
