#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

launchctl bootout "gui/$(id -u)/mesa-mobile-agent" 2>/dev/null || true

if [[ -f "$BASE_DIR/logs/agent.pid" ]]; then
  kill "$(cat "$BASE_DIR/logs/agent.pid")" 2>/dev/null || true
  rm -f "$BASE_DIR/logs/agent.pid"
fi

for pid in $(pgrep -f "./venv/bin/python -u agent.py" 2>/dev/null || true); do
  cwd="$(lsof -p "$pid" 2>/dev/null | awk '$4=="cwd" {print $9}')"
  if [[ "$cwd" == "$BASE_DIR" ]]; then
    kill -9 "$pid" 2>/dev/null || true
  fi
done

echo "mesa agent stopped"
