#!/bin/bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"
mkdir -p logs

# stop duplicate mesa agents in this repo only
for pid in $(pgrep -f "./venv/bin/python -u agent.py" 2>/dev/null || true); do
  cwd="$(lsof -p "$pid" 2>/dev/null | awk '$4=="cwd" {print $9}')"
  if [[ "$cwd" == "$BASE_DIR" ]]; then
    kill "$pid" 2>/dev/null || true
  fi
done
sleep 1

launchctl bootout "gui/$(id -u)/mesa-mobile-agent" 2>/dev/null || true

nohup ./venv/bin/python -u agent.py >> logs/agent.out.log 2>> logs/agent.err.log &
echo "$!" > logs/agent.pid
echo "mesa agent started pid=$(cat logs/agent.pid)"
sleep 2
tail -3 logs/agent.err.log
