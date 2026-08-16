#!/bin/bash

set -euo pipefail

readonly DERIVED_DATA_PATH="${1:-DerivedData/ReleaseValidation}"
readonly RESOLVED_FILE="Wardrobe.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
readonly APP_PATH="${2:-${DERIVED_DATA_PATH}/Build/Products/Release-iphonesimulator/Wardrobe.app}"

fail() {
  echo "Release verification failed: $*" >&2
  exit 1
}

[[ -f "${RESOLVED_FILE}" ]] || fail "missing ${RESOLVED_FILE}"
[[ -d "${APP_PATH}" ]] || fail "missing Release app at ${APP_PATH}"

/usr/bin/python3 - "${RESOLVED_FILE}" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    resolved = json.load(handle)

pins = resolved.get("pins", resolved.get("object", {}).get("pins", []))
google = next(
    (pin for pin in pins if pin.get("identity", pin.get("package", "")).lower() == "googlesignin-ios"),
    None,
)
if google is None:
    raise SystemExit("GoogleSignIn-iOS is not present in Package.resolved")
version = google.get("state", {}).get("version")
if version != "9.2.0":
    raise SystemExit(f"GoogleSignIn-iOS must resolve to 9.2.0, got {version!r}")
PY

readonly INFO_PLIST="${APP_PATH}/Info.plist"
[[ -f "${INFO_PLIST}" ]] || fail "built app has no Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :UILaunchScreen:UIColorName' "${INFO_PLIST}")" == "LaunchBackground" ]] \
  || fail "built app does not use the branded launch background"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :UILaunchScreen:UIImageName' "${INFO_PLIST}")" == "LaunchMark" ]] \
  || fail "built app does not use the branded launch mark"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :UILaunchScreen:UIImageRespectsSafeAreaInsets' "${INFO_PLIST}")" == "true" ]] \
  || fail "built app launch mark does not respect safe-area insets"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :ITSAppUsesNonExemptEncryption' "${INFO_PLIST}")" == "false" ]] \
  || fail "unexpected encryption declaration"
[[ -n "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}")" ]] \
  || fail "missing marketing version"
[[ -n "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${INFO_PLIST}")" ]] \
  || fail "missing build number"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "${INFO_PLIST}")" == "Wardrobe Stylist" ]] \
  || fail "CFBundleDisplayName must be Wardrobe Stylist"

# A shared bearer is a public-client secret and must never remain wired into an artifact,
# including as an empty plist key.
if /usr/libexec/PlistBuddy -c 'Print :BackendDeviceToken' "${INFO_PLIST}" >/dev/null 2>&1; then
  fail "built app contains the obsolete BackendDeviceToken key"
fi

# Xcode strips App Attest from simulator signatures because DeviceCheck isn't available there.
# TestFlight and App Store device products must retain the production entitlement, so inspect the
# signed product whenever this script is pointed at an iphoneos app from an archive.
readonly BUILT_PLATFORM="$(
  /usr/libexec/PlistBuddy -c 'Print :DTPlatformName' "${INFO_PLIST}" 2>/dev/null
)"
case "${BUILT_PLATFORM}" in
  iphoneos)
    readonly ENTITLEMENTS_PLIST="$(/usr/bin/mktemp -t wardrobe-release-entitlements)"
    trap '/bin/rm -f "${ENTITLEMENTS_PLIST}"' EXIT
    /usr/bin/codesign -d --entitlements :- "${APP_PATH}" >"${ENTITLEMENTS_PLIST}" 2>/dev/null \
      || fail "could not read the built app entitlements"
    /usr/bin/plutil -lint "${ENTITLEMENTS_PLIST}" >/dev/null \
      || fail "built app entitlements are invalid"
    if ! APP_ATTEST_ENVIRONMENT="$(
      /usr/bin/plutil -extract com.apple.developer.devicecheck.appattest-environment \
        raw -o - "${ENTITLEMENTS_PLIST}" 2>/dev/null
    )"; then
      fail "device app has no App Attest environment entitlement"
    fi
    readonly APP_ATTEST_ENVIRONMENT
    [[ "${APP_ATTEST_ENVIRONMENT}" == "production" ]] \
      || fail "device app App Attest environment must be production, got ${APP_ATTEST_ENVIRONMENT}"
    readonly APP_ATTEST_RESULT="production App Attest entitlement"
    ;;
  iphonesimulator)
    readonly APP_ATTEST_RESULT="simulator artifact (signed entitlement deferred to device archive)"
    ;;
  *)
    fail "unexpected built platform ${BUILT_PLATFORM:-<missing>}"
    ;;
esac

readonly APP_PRIVACY_MANIFEST="${APP_PATH}/PrivacyInfo.xcprivacy"
[[ -f "${APP_PRIVACY_MANIFEST}" ]] || fail "built app has no app-owned PrivacyInfo.xcprivacy"
/usr/bin/plutil -lint "${APP_PRIVACY_MANIFEST}" >/dev/null \
  || fail "app-owned PrivacyInfo.xcprivacy is invalid"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType' "${APP_PRIVACY_MANIFEST}")" == "NSPrivacyAccessedAPICategoryUserDefaults" ]] \
  || fail "app privacy manifest does not declare UserDefaults"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0' "${APP_PRIVACY_MANIFEST}")" == "CA92.1" ]] \
  || fail "app privacy manifest does not declare UserDefaults reason CA92.1"

readonly -a REQUIRED_SDK_BUNDLES=(
  "GoogleSignIn_GoogleSignIn.bundle"
  "GoogleSignIn_GoogleSignInSwift.bundle"
  "AppAuth_AppAuth.bundle"
  "AppAuth_AppAuthCore.bundle"
  "Promises_FBLPromises.bundle"
  "GoogleUtilities_GoogleUtilities-Logger.bundle"
  "GoogleUtilities_GoogleUtilities-UserDefaults.bundle"
  "GoogleUtilities_GoogleUtilities-Environment.bundle"
  "GTMAppAuth_GTMAppAuth.bundle"
  "GTMSessionFetcher_GTMSessionFetcherCore.bundle"
)

manifest_count=0
for bundle_name in "${REQUIRED_SDK_BUNDLES[@]}"; do
  bundle_path="${APP_PATH}/${bundle_name}"
  [[ -d "${bundle_path}" ]] || fail "required SDK resource bundle is missing: ${bundle_name}"
  manifest_path="${bundle_path}/PrivacyInfo.xcprivacy"
  [[ -f "${manifest_path}" ]] || fail "${bundle_name} is embedded without PrivacyInfo.xcprivacy"
  /usr/bin/plutil -lint "${manifest_path}" >/dev/null \
    || fail "${bundle_name} has an invalid PrivacyInfo.xcprivacy"
  manifest_count=$((manifest_count + 1))
done

while IFS= read -r manifest_path; do
  /usr/bin/plutil -lint "${manifest_path}" >/dev/null \
    || fail "embedded privacy manifest is invalid: ${manifest_path#${APP_PATH}/}"
done < <(/usr/bin/find "${APP_PATH}" -name PrivacyInfo.xcprivacy -type f -print)

echo "Release artifact verified: ${APP_ATTEST_RESULT}, no shared bearer, GoogleSignIn 9.2.0, app manifest, required plist values, and ${manifest_count} SDK privacy manifest(s)."
