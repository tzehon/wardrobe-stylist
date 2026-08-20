#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DERIVED_DATA_PATH="${1:-DerivedData/ReleaseValidation}"
readonly APP_PATH="${2:-${DERIVED_DATA_PATH}/Build/Products/Release-iphonesimulator/Wardrobe.app}"

fail() {
  echo "Release verification failed: $*" >&2
  exit 1
}

[[ -d "${APP_PATH}" ]] || fail "missing Release app at ${APP_PATH}"
/usr/bin/codesign --verify --deep --strict "${APP_PATH}" >/dev/null 2>&1 \
  || fail "built app code signature is invalid"

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
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${INFO_PLIST}")" == "com.tth.Wardrobe" ]] \
  || fail "CFBundleIdentifier must be com.tth.Wardrobe"

if /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity' "${INFO_PLIST}" >/dev/null 2>&1; then
  fail "built app contains an App Transport Security exception"
fi

# A shared bearer is a public-client secret and must never remain wired into an artifact,
# including as an empty plist key.
if /usr/libexec/PlistBuddy -c 'Print :BackendDeviceToken' "${INFO_PLIST}" >/dev/null 2>&1; then
  fail "built app contains the obsolete BackendDeviceToken key"
fi
if /usr/libexec/PlistBuddy -c 'Print :GIDClientID' "${INFO_PLIST}" >/dev/null 2>&1; then
  fail "built app contains a legacy provider client identifier"
fi
if /usr/libexec/PlistBuddy -c 'Print :BGTaskSchedulerPermittedIdentifiers' "${INFO_PLIST}" >/dev/null 2>&1; then
  fail "built app contains background task identifiers"
fi
if /usr/libexec/PlistBuddy -c 'Print :UIBackgroundModes' "${INFO_PLIST}" >/dev/null 2>&1; then
  fail "built app contains background execution modes"
fi

readonly APP_EXECUTABLE="${APP_PATH}/Wardrobe"
[[ -f "${APP_EXECUTABLE}" ]] || fail "built app executable is missing"
if /usr/bin/strings "${APP_EXECUTABLE}" | /usr/bin/grep -F '/extract' >/dev/null; then
  fail "built app contains the removed extraction route"
fi
if /usr/bin/strings "${APP_EXECUTABLE}" | /usr/bin/grep -F 'gmail.readonly' >/dev/null; then
  fail "built app contains the removed mail authorization scope"
fi

# Xcode strips App Attest from simulator signatures because DeviceCheck isn't available there.
# TestFlight and App Store device products must retain the production entitlement, so inspect the
# signed product whenever this script is pointed at an iphoneos app from an archive.
readonly BUILT_PLATFORM="$(
  /usr/libexec/PlistBuddy -c 'Print :DTPlatformName' "${INFO_PLIST}" 2>/dev/null
)"
case "${BUILT_PLATFORM}" in
  iphoneos)
    /usr/bin/python3 "${SCRIPT_DIR}/validate_public_release.py" "${INFO_PLIST}"
    readonly ENTITLEMENTS_PLIST="$(/usr/bin/mktemp -t wardrobe-release-entitlements)"
    readonly PROFILE_PLIST="$(/usr/bin/mktemp -t wardrobe-release-profile)"
    trap '/bin/rm -f "${ENTITLEMENTS_PLIST}" "${PROFILE_PLIST}"' EXIT
    /usr/bin/codesign --display --entitlements - --xml "${APP_PATH}" \
      >"${ENTITLEMENTS_PLIST}" 2>/dev/null \
      || fail "could not read the built app entitlements"
    /usr/bin/plutil -lint "${ENTITLEMENTS_PLIST}" >/dev/null \
      || fail "built app entitlements are invalid"
    readonly EMBEDDED_PROFILE="${APP_PATH}/embedded.mobileprovision"
    [[ -f "${EMBEDDED_PROFILE}" ]] || fail "device app has no embedded provisioning profile"
    /usr/bin/security cms -D -i "${EMBEDDED_PROFILE}" -o "${PROFILE_PLIST}" >/dev/null 2>&1 \
      || fail "could not decode the embedded provisioning profile"
    /usr/bin/plutil -lint "${PROFILE_PLIST}" >/dev/null \
      || fail "embedded provisioning profile is invalid"
    /usr/bin/python3 "${SCRIPT_DIR}/verify_release_identity.py" \
      "${INFO_PLIST}" "${ENTITLEMENTS_PLIST}" "${PROFILE_PLIST}"
    readonly APP_ATTEST_RESULT="production App Attest entitlement and matching provisioning profile"
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

readonly -a FORBIDDEN_SDK_BUNDLES=(
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

for bundle_name in "${FORBIDDEN_SDK_BUNDLES[@]}"; do
  bundle_path="${APP_PATH}/${bundle_name}"
  [[ ! -e "${bundle_path}" ]] || fail "removed SDK resource bundle is still embedded: ${bundle_name}"
done

while IFS= read -r manifest_path; do
  /usr/bin/plutil -lint "${manifest_path}" >/dev/null \
    || fail "embedded privacy manifest is invalid: ${manifest_path#${APP_PATH}/}"
done < <(/usr/bin/find "${APP_PATH}" -name PrivacyInfo.xcprivacy -type f -print)

echo "Release artifact verified: ${APP_ATTEST_RESULT}, no shared bearer, no legacy provider/extraction artifacts, app manifest, and required plist values."
