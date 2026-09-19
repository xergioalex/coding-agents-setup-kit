#!/usr/bin/env bash
# Idempotent installer / onboard for coding-agents-setup-kit (macOS, Linux, WSL,
# and Git Bash on Windows — the PowerShell path is install.ps1).
#
# Usage:
#   ./install.sh              wrappers + PATH + env skeleton (does not touch CLIs)
#   ./install.sh --onboard    detect what is already installed, fill gaps including CLIs
#   ./install.sh --clis       same CLI gap-fill without reprinting the full plan
#   ./install.sh --no-path    do not append PATH to your shell rc
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${KIT_ROOT}/lib/common.sh"
# shellcheck disable=SC1091
source "${KIT_ROOT}/lib/onboard.sh"

INSTALL_CLIS=0
ONBOARD=0
TOUCH_PATH=1

for arg in "$@"; do
  case "$arg" in
    --clis) INSTALL_CLIS=1 ;;
    --onboard) ONBOARD=1; INSTALL_CLIS=1 ;;
    --no-path) TOUCH_PATH=0 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./install.sh [--onboard] [--clis] [--no-path]

  (no flags)   Copy wrappers, wire PATH, create the env file if missing.
               Never overwrites an existing env file. Never reinstalls a CLI.
  --onboard    Print what is already installed, then fill only the gaps
               (wrappers + missing official CLIs). Safe on a machine that
               already has Claude, Codex, Cursor, OpenCode, Grok or Herdr.
  --clis       Install missing official CLIs only (skipped when already present).
  --no-path    Do not append the PATH block to your shell rc.

Windows (PowerShell): run .\install.ps1 instead.
EOF
      exit 0
      ;;
    *) echo "unknown arg: $arg" >&2; exit 1 ;;
  esac
done

export PATH="${HOME}/.local/share/coding-agents-kit/bin:${HOME}/.local/bin:${PATH}"

if [[ "${ONBOARD}" -eq 1 ]]; then
  echo "=== Before ==="
  agentkit_status
  agentkit_plan
  echo ""
  echo "=== Applying ==="
fi

agentkit_copy_wrappers "${KIT_ROOT}"
cp "${KIT_ROOT}/env.example" "$(agentkit_dest)/env.example"
agentkit_ensure_env "${KIT_ROOT}/env.example"
if [[ "${TOUCH_PATH}" -eq 1 ]]; then
  agentkit_ensure_path
fi

if [[ "${INSTALL_CLIS}" -eq 1 ]]; then
  agentkit_install_missing_clis
fi

export PATH="${HOME}/.local/share/coding-agents-kit/bin:${HOME}/.local/bin:${PATH}"
# shellcheck disable=SC1091
source "${KIT_ROOT}/lib/common.sh"

echo ""
echo "=== After ==="
agentkit_status
echo ""
echo "Open a new terminal (or re-source your shell rc)."
echo "Fill your keys locally in $(agentkit_env_file) — never paste them into a chat."
echo "Then: agentkit status"
