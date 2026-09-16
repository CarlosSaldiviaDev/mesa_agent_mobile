#!/bin/bash
# shared agent helpers — flutter without a tty (Cursor agent, launchd, Telegram subprocess)

_common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_agent_base="$(cd "$_common_dir/.." && pwd)"

if [[ -f "$_agent_base/config/agent.env" ]]; then
  # shellcheck disable=SC1091
  source "$_agent_base/config/agent.env"
fi

FLUTTER_BIN="${FLUTTER:-flutter}"
export PATH="$(dirname "$FLUTTER_BIN"):${PATH:-}"

# parent may close fd 0; redirect stdin so flutter shutdown hooks do not errno 9
mesa_flutter() {
  "$FLUTTER_BIN" "$@" 0</dev/null
}

# nested python (play token, etc.) needs valid stdin when agent has no tty
mesa_python() {
  local py="${1:?python binary}"
  shift
  "$py" "$@" 0</dev/null
}
