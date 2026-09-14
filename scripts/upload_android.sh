#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$BASE_DIR/config/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE — copy config/.env.example and fill ANDROID_PACKAGE_NAME / Play + Apple secrets"
  exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

ARTIFACTS="$BASE_DIR/artifacts/android"
APP_ID="${ANDROID_PACKAGE_NAME:-org.mesa.crsa1899}"
TRACK="${PLAY_TRACK:-internal}"
if [[ -x "$BASE_DIR/venv/bin/python" ]]; then
  PYTHON="$BASE_DIR/venv/bin/python"
else
  PYTHON="${PYTHON:-python3}"
fi
PLAY_TOKEN_SCRIPT="$BASE_DIR/scripts/play_token.py"
PLAY_SA="$BASE_DIR/config/play-service-account.json"

if [[ ! -f "$PLAY_SA" ]]; then
  echo "missing $PLAY_SA — copy your Play Console service account JSON there"
  exit 1
fi

echo "uploading android to Play track=$TRACK app=$APP_ID"
TOKEN="$("$PYTHON" "$PLAY_TOKEN_SCRIPT")"
[[ -n "$TOKEN" ]] || { echo "token failed"; exit 1; }
echo "play token ok"

AAB_PATH=$(ls -t "$ARTIFACTS"/*.aab | head -n 1)
[[ -f "$AAB_PATH" ]] || { echo "no aab in $ARTIFACTS"; exit 1; }
echo "bundle: $AAB_PATH"

EDIT_RESPONSE=$(curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$APP_ID/edits" || true)
EDIT_ID=$(echo "$EDIT_RESPONSE" | grep -o '"id": *"[^"]*"' | head -n 1 | cut -d'"' -f4 || true)
if [[ -z "$EDIT_ID" ]]; then
  echo "edit failed: $EDIT_RESPONSE"
  exit 1
fi
echo "edit id: $EDIT_ID"

UPLOAD_URL="https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${APP_ID}/edits/${EDIT_ID}/bundles?uploadType=media"
HTTP_CODE=$(curl -sS -o /tmp/mesa_bundle.json -w "%{http_code}" -X POST \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @"${AAB_PATH}" \
  "${UPLOAD_URL}" || true)
BUNDLE_RESPONSE=$(cat /tmp/mesa_bundle.json 2>/dev/null || true)
echo "upload http $HTTP_CODE"
echo "$BUNDLE_RESPONSE"
[[ "$HTTP_CODE" == "200" ]] || { echo "bundle upload failed"; exit 1; }

VERSION_CODE=$(echo "$BUNDLE_RESPONSE" | grep -o '"versionCode": *[0-9]*' | head -n 1 | grep -o '[0-9]*' || true)
[[ -n "$VERSION_CODE" ]] || { echo "no versionCode in: $BUNDLE_RESPONSE"; exit 1; }

TRACK_RESPONSE=$(curl -sS -X PUT \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"releases\":[{\"name\":\"auto-release\",\"status\":\"completed\",\"versionCodes\":[$VERSION_CODE]}]}" \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$APP_ID/edits/$EDIT_ID/tracks/$TRACK" || true)
echo "track response: $TRACK_RESPONSE"

COMMIT_RESPONSE=$(curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$APP_ID/edits/$EDIT_ID:commit" || true)
echo "commit response: $COMMIT_RESPONSE"

echo "android upload finished versionCode=$VERSION_CODE"
