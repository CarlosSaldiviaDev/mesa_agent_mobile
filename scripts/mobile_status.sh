#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/_common.sh"
PROJECT="$MESA_MOBILE_REPO"

echo "mesa mobile status"
echo "----------------------------------"
echo "host: $(hostname)"
mesa_flutter --version 2>/dev/null | head -3 || true
cd "$PROJECT"
echo "pubspec: $(grep '^version:' pubspec.yaml)"
echo "android versionName/Code from build.gradle.kts:"
grep -E 'versionCode|versionName' android/app/build.gradle.kts | head -5 || true
echo "ios CFBundleShortVersionString from Info.plist:"
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" ios/Runner/Info.plist 2>/dev/null || true
