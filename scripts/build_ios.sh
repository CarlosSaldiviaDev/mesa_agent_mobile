#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config/agent.env"
FLUTTER="${FLUTTER:-flutter}"
PROJECT="$MESA_MOBILE_REPO"
DART_DEFINE_FILE="${DART_DEFINE_FILE:-config_production.json}"
ARTIFACTS="$BASE_DIR/artifacts/ios"
EXPORT_PLIST="$BASE_DIR/config/exportOptions.plist"

[[ -f "$EXPORT_PLIST" ]] || { echo "missing exportOptions.plist — copy example and set teamID"; exit 1; }

cd "$PROJECT" || exit 1
VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
COMMIT=$(git -C "$PROJECT" rev-parse --short HEAD 2>/dev/null || echo local)

"$FLUTTER" clean
"$FLUTTER" pub get
(cd ios && rm -rf Pods && pod install --repo-update)

"$FLUTTER" build ios --release --dart-define-from-file="$DART_DEFINE_FILE"

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
