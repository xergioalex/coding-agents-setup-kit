#!/usr/bin/env bash
# Shared helpers for coding-agents-setup-kit wrappers. No secrets printed.
#
# Sourced by every wrapper in bin/. Loads the user's env file into THIS process
# only, defines the fail-fast guards (which print variable names, never values),
# the OS probe, and the Cursor-vs-Grok resolver.

agentkit_load_env() {
  local env_file="${AGENTKIT_ENV:-${HOME}/.config/coding-agents-kit/env}"
  if [[ -f "${env_file}" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "${env_file}"
    set +a
  fi
}

agentkit_die() {
  printf 'agentkit: %s\n' "$*" >&2
  return 1
}

agentkit_warn() {
  printf 'agentkit: %s\n' "$*" >&2
}

# macos | linux | windows | unknown. Windows is reported when this bash is
# Git Bash / MSYS / Cygwin; a WSL shell reports linux, which is correct — from
# the kit's point of view it IS a Linux machine with its own $HOME.
agentkit_os() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) printf 'macos' ;;
    Linux)  printf 'linux' ;;
    MINGW*|MSYS*|CYGWIN*) printf 'windows' ;;
    *)      printf 'unknown' ;;
  esac
}

agentkit_require_cmd() {
  command -v "$1" >/dev/null 2>&1 || agentkit_die "$1 is not on PATH. Run ./install.sh --onboard, or see INSTALL.md."
}

agentkit_check_cline_binary() {
  [[ "$(uname -s)" == "Darwin" ]] || return 0
  command -v codesign >/dev/null 2>&1 || return 0

  local launcher binary
  launcher="$(command -v cline 2>/dev/null || true)"
  [[ -n "${launcher}" ]] || return 0
  binary="$(cd "$(dirname "${launcher}")" && pwd)/.cline"
  [[ -f "${binary}" ]] || return 0
  if ! codesign --verify "${binary}" >/dev/null 2>&1; then
    agentkit_die "Cline binary has an invalid macOS signature: ${binary}. Run 'codesign --force --sign - ${binary}' or reinstall Cline."
    return 1
  fi
}

agentkit_require_env() {
  local name="$1"
  [[ -n "${!name:-}" ]] || agentkit_die "$name is not set. Add it to ${AGENTKIT_ENV:-$HOME/.config/coding-agents-kit/env}."
}

agentkit_azure_base_url() {
  if [[ -n "${AZURE_OPENAI_BASE_URL:-}" ]]; then
    printf '%s' "${AZURE_OPENAI_BASE_URL}"
  elif [[ -n "${AZURE_OPENAI_RESOURCE:-}" ]]; then
    printf 'https://%s.services.ai.azure.com/openai/v1' "${AZURE_OPENAI_RESOURCE}"
  else
    return 1
  fi
}

agentkit_require_azure() {
  agentkit_require_env AZURE_OPENAI_API_KEY || return 1
  agentkit_azure_base_url >/dev/null || agentkit_die "Set AZURE_OPENAI_RESOURCE or AZURE_OPENAI_BASE_URL."
  # Deployment names are yours, so the kit cannot guess one: a wrong model id
  # surfaces as an opaque provider error much later. Fail here, with the name.
  agentkit_require_env AZURE_OPENAI_MODEL_DAILY || return 1
}

agentkit_require_xai() {
  agentkit_require_env XAI_API_KEY || return 1
}

agentkit_require_zai() {
  agentkit_require_env ZAI_CODING_API_KEY || return 1
}

# --- Cursor Agent CLI resolution -------------------------------------------
# Cursor's installer symlinks BOTH ~/.local/bin/agent and ~/.local/bin/cursor-agent
# to ~/.local/share/cursor-agent/versions/<v>/cursor-agent. The xAI Grok CLI
# installer ALSO ships an `agent` symlink (~/.grok/bin/agent, ~/.local/bin/agent),
# so a bare `command -v agent` is not proof that Cursor is installed.

# True when the given executable is the Cursor Agent CLI (never Grok).
agentkit_is_cursor_binary() {
  local path="$1" resolved banner
  resolved="$(readlink -f "${path}" 2>/dev/null || printf '%s' "${path}")"
  case "${resolved}" in
    */.grok/*|*grok-macos*|*grok-linux*|*grok-windows*) return 1 ;;
    */cursor-agent/*|*/cursor-agent) return 0 ;;
  esac
  banner="$("${path}" --version 2>/dev/null | head -n1)"
  case "${banner}" in
    grok*|Grok*) return 1 ;;
  esac
  [[ "$(basename "${path}")" == "cursor-agent" ]] && return 0
  "${path}" --help 2>/dev/null | grep -qi 'cursor'
}

# Prints the Cursor Agent CLI path (preferring the unambiguous `cursor-agent`
# name), or returns 1 when Cursor is not installed.
agentkit_cursor_bin() {
  local candidate path versions latest
  for candidate in cursor-agent agent; do
    path="$(command -v "${candidate}" 2>/dev/null)" || continue
    if agentkit_is_cursor_binary "${path}"; then
      printf '%s' "${path}"
      return 0
    fi
  done
  # ~/.local/bin/agent may be shadowed by Grok's PATH entry; look at Cursor's own tree.
  versions="${HOME}/.local/share/cursor-agent/versions"
  if [[ -d "${versions}" ]]; then
    latest=""
    for path in "${versions}"/*/cursor-agent; do
      [[ -x "${path}" ]] || continue
      if [[ -z "${latest}" || "${path}" -nt "${latest}" ]]; then
        latest="${path}"
      fi
    done
    if [[ -n "${latest}" ]]; then
      printf '%s' "${latest}"
      return 0
    fi
  fi
  return 1
}

# The host-vs-container check lives in host.sh, which has no side effects, so a
# command that must not load the user's env file can source that alone.
# shellcheck source=/dev/null
. "$(dirname "${BASH_SOURCE[0]}")/host.sh"

agentkit_load_env
