#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/_common.sh"
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$MESA_MOBILE_REPO"
DART_DEFINE_FILE="${DART_DEFINE_FILE:-config_production.json}"
ARTIFACTS="$BASE_DIR/artifacts/android"

cd "$PROJECT" || exit 1
mesa_flutter clean
mesa_flutter pub get
mesa_flutter build appbundle --release --dart-define-from-file="$DART_DEFINE_FILE"

mkdir -p "$ARTIFACTS"
cp -f build/app/outputs/bundle/release/*.aab "$ARTIFACTS/"
ls -la "$ARTIFACTS"
echo "android build finished"
