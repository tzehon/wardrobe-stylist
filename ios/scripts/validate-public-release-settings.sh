#!/bin/bash

set -euo pipefail

# Simulator Release builds exercise compilation and artifact structure in CI. The strict
# configuration gate is for installable device archives, which are the artifacts that can
# reach TestFlight/App Store Connect.
if [[ "${CONFIGURATION:-}" != "Release" || "${PLATFORM_NAME:-}" != "iphoneos" ]]; then
  exit 0
fi

readonly INFO_PLIST_PATH="${1:?expected built Info.plist path}"
if [[ "${APP_ATTEST_ENVIRONMENT:-}" != "production" ]]; then
  echo "Public Release configuration failed: APP_ATTEST_ENVIRONMENT must be production" >&2
  exit 1
fi
exec /usr/bin/python3 "${SRCROOT}/scripts/validate_public_release.py" "${INFO_PLIST_PATH}"
