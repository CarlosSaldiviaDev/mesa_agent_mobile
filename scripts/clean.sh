#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "$0")/_common.sh"
PROJECT="$MESA_MOBILE_REPO"

cd "$PROJECT" || exit 1
mesa_flutter clean
mesa_flutter pub get
echo "clean done"
