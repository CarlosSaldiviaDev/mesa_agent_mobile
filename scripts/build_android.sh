#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config/agent.env"
FLUTTER="${FLUTTER:-flutter}"
PROJECT="$MESA_MOBILE_REPO"
DART_DEFINE_FILE="${DART_DEFINE_FILE:-config_production.json}"
ARTIFACTS="$BASE_DIR/artifacts/android"

cd "$PROJECT" || exit 1
"$FLUTTER" clean
"$FLUTTER" pub get
"$FLUTTER" build appbundle --release --dart-define-from-file="$DART_DEFINE_FILE"

mkdir -p "$ARTIFACTS"
cp -f build/app/outputs/bundle/release/*.aab "$ARTIFACTS/"
ls -la "$ARTIFACTS"
echo "android build finished"
