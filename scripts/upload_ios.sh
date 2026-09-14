#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$BASE_DIR/config/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE — copy config/.env.example and fill Apple / ASC secrets"
  exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

ARTIFACTS="$BASE_DIR/artifacts/ios"
IPA_PATH=$(ls -t "$ARTIFACTS"/*.ipa | head -n 1)
[[ -f "$IPA_PATH" ]] || { echo "ipa not found"; exit 1; }

BUNDLE_ID="${IOS_BUNDLE_ID:-org.mesa.crsa1899}"
APPLE_APP_NUMERIC_ID="${APPLE_APP_NUMERIC_ID:?set APPLE_APP_NUMERIC_ID}"
ASC_PUBLIC_ID="${ASC_PUBLIC_ID:?set ASC_PUBLIC_ID}"

TMP_DIR=$(mktemp -d)
unzip -q "$IPA_PATH" -d "$TMP_DIR"
APP_PATH=$(find "$TMP_DIR/Payload" -name "*.app" | head -n 1)
PLIST="$APP_PATH/Info.plist"
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
BUNDLE_SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
rm -rf "$TMP_DIR"

echo "ipa: $IPA_PATH"
echo "bundle: $BUNDLE_ID version: $BUNDLE_SHORT_VERSION ($BUNDLE_VERSION)"

xcrun altool \
  --upload-package "$IPA_PATH" \
  --type ios \
  --apple-id "$APPLE_APP_NUMERIC_ID" \
  --bundle-id "$BUNDLE_ID" \
  --bundle-version "$BUNDLE_VERSION" \
  --bundle-short-version-string "$BUNDLE_SHORT_VERSION" \
  --asc-public-id "$ASC_PUBLIC_ID" \
  --username "$APPLE_ID" \
  --password "$APPLE_APP_PASSWORD" \
  --show-progress

echo "ios upload finished"
