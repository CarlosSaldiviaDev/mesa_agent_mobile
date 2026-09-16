#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/_common.sh"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "mesa mobile doctor"
echo "----------------------------------"
echo "host: $(hostname) user: $(whoami)"
[[ -x "$FLUTTER_BIN" ]] && mesa_flutter --version || echo "flutter MISSING: $FLUTTER_BIN"
command -v java >/dev/null && java -version 2>&1 | head -1 || echo "java MISSING"
command -v adb >/dev/null && adb version | head -1 || echo "adb MISSING"
command -v xcodebuild >/dev/null && xcodebuild -version || echo "xcode MISSING"
command -v pod >/dev/null && pod --version || echo "cocoapods MISSING"
PROJECT="$MESA_MOBILE_REPO"
[[ -d "$PROJECT" ]] && echo "project OK: $PROJECT" || echo "project MISSING: $PROJECT"
[[ -f "$PROJECT/$DART_DEFINE_FILE" ]] && echo "dart-define OK: $DART_DEFINE_FILE" || echo "dart-define MISSING: ${DART_DEFINE_FILE:-config_production.json}"
[[ -f "$PROJECT/android/key.properties" ]] && echo "android signing OK" || echo "android signing MISSING (key.properties)"
[[ -f "$BASE_DIR/config/play-service-account.json" ]] && echo "play json OK" || echo "play json MISSING (optional until android upload)"
[[ -f "$BASE_DIR/config/exportOptions.plist" ]] && echo "exportOptions.plist OK" || echo "exportOptions.plist MISSING (required for ios build)"
[[ -f "$BASE_DIR/config/.env" ]] && echo ".env OK" || echo ".env MISSING"
echo "doctor finished"
