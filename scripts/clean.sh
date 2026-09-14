#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config/agent.env"
FLUTTER="${FLUTTER:-flutter}"
PROJECT="$MESA_MOBILE_REPO"

cd "$PROJECT" || exit 1
"$FLUTTER" clean
"$FLUTTER" pub get
echo "clean done"
