#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/_common.sh"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$MESA_MOBILE_REPO"
DART_DEFINE_FILE="${DART_DEFINE_FILE:-config_production.json}"
ARTIFACTS="$BASE_DIR/artifacts/ios"
EXPORT_PLIST="$BASE_DIR/config/exportOptions.plist"

[[ -f "$EXPORT_PLIST" ]] || { echo "missing exportOptions.plist — copy example and set teamID"; exit 1; }

cd "$PROJECT" || exit 1
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
COMMIT=$(git -C "$PROJECT" rev-parse --short HEAD 2>/dev/null || echo local)

mesa_flutter clean
mesa_flutter pub get

pod_install_with_retry() {
  local attempt=1
  local max=3
  while (( attempt <= max )); do
    echo "pod install attempt $attempt/$max"
    if (( attempt == 1 )); then
      pod install --repo-update && return 0
    else
      pod install && return 0
    fi
    echo "pod install failed, retrying in 20s..."
    sleep 20
    attempt=$((attempt + 1))
  done
  return 1
}

(
  cd ios
  rm -rf Pods
  pod_install_with_retry
)

mesa_flutter build ios --release --dart-define-from-file="$DART_DEFINE_FILE"

ARCHIVE_PATH="build/ios/archive/Runner.xcarchive"
xcodebuild archive \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates

EXPORT_PATH="build/ios/ipa"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates

IPA_PATH=$(find "$EXPORT_PATH" -name "*.ipa" | head -n 1)
mkdir -p "$ARTIFACTS"
TARGET="$ARTIFACTS/mesa-${VERSION}-${COMMIT}.ipa"
cp "$IPA_PATH" "$TARGET"
echo "ios artifact: $TARGET"
