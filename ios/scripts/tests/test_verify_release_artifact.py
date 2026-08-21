#!/usr/bin/env python3

from __future__ import annotations

import json
import plistlib
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "verify-release-artifact.sh"


class ReleaseArtifactScriptTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self._temporary_directory.name)

    def tearDown(self) -> None:
        self._temporary_directory.cleanup()

    def _make_app(
        self,
        *,
        executable_marker: str = "safe-release-fixture",
        nested_forbidden_bundle: str | None = None,
        harmless_bundle_reference: bool = False,
    ) -> Path:
        app_path = self.root / "Wardrobe.app"
        app_path.mkdir()

        info = {
            "CFBundleDisplayName": "Wardrobe Stylist",
            "CFBundleExecutable": "Wardrobe",
            "CFBundleIdentifier": "com.tth.Wardrobe",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "4",
            "DTPlatformName": "iphonesimulator",
            "ITSAppUsesNonExemptEncryption": False,
            "UILaunchScreen": {
                "UIColorName": "LaunchBackground",
                "UIImageName": "LaunchMark",
                "UIImageRespectsSafeAreaInsets": True,
            },
        }
        with (app_path / "Info.plist").open("wb") as handle:
            plistlib.dump(info, handle)

        privacy_manifest = {
            "NSPrivacyAccessedAPITypes": [
                {
                    "NSPrivacyAccessedAPIType": (
                        "NSPrivacyAccessedAPICategoryUserDefaults"
                    ),
                    "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
                }
            ]
        }
        with (app_path / "PrivacyInfo.xcprivacy").open("wb") as handle:
            plistlib.dump(privacy_manifest, handle)

        source = self.root / "fixture.c"
        source.write_text(
            "__attribute__((used)) static const char marker[] = "
            f"{json.dumps(executable_marker)};\n"
            "int main(void) { return marker[0] == '\\0'; }\n",
            encoding="utf-8",
        )
        subprocess.run(
            [
                shutil.which("clang") or "clang",
                str(source),
                "-o",
                str(app_path / "Wardrobe"),
            ],
            check=True,
            capture_output=True,
            text=True,
        )

        if nested_forbidden_bundle is not None:
            (
                app_path
                / "Frameworks"
                / "Fixture.framework"
                / "Resources"
                / nested_forbidden_bundle
            ).mkdir(parents=True)
        if harmless_bundle_reference:
            (app_path / "SDK-removal-notes.txt").write_text(
                "GoogleSignIn_GoogleSignIn.bundle must remain absent.\n",
                encoding="utf-8",
            )

        subprocess.run(
            [
                "/usr/bin/codesign",
                "--force",
                "--sign",
                "-",
                "--timestamp=none",
                str(app_path),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        return app_path

    def _verify(self, app_path: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [str(SCRIPT), str(self.root / "DerivedData"), str(app_path)],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_accepts_clean_simulator_artifact_without_bundle_name_false_positives(
        self,
    ) -> None:
        result = self._verify(self._make_app(harmless_bundle_reference=True))

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Release artifact verified", result.stdout)

    def test_rejects_removed_extraction_route_in_executable(self) -> None:
        result = self._verify(self._make_app(executable_marker="/extract"))

        self.assertEqual(result.returncode, 1)
        self.assertIn("removed extraction route", result.stderr)

    def test_rejects_removed_mail_scope_in_executable(self) -> None:
        result = self._verify(self._make_app(executable_marker="gmail.readonly"))

        self.assertEqual(result.returncode, 1)
        self.assertIn("removed mail authorization scope", result.stderr)

    def test_rejects_forbidden_sdk_bundle_nested_in_app(self) -> None:
        result = self._verify(
            self._make_app(nested_forbidden_bundle="GoogleSignIn_GoogleSignIn.bundle")
        )

        self.assertEqual(result.returncode, 1)
        self.assertIn("removed SDK resource bundle is still embedded", result.stderr)
        self.assertIn("Frameworks/Fixture.framework/Resources", result.stderr)


if __name__ == "__main__":
    unittest.main()
