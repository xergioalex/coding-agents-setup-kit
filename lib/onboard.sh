#!/usr/bin/env bash
# Detection + gap-fill for coding-agents-setup-kit. Never prints secret values.
#
# Sourced by install.sh and bin/agentkit. Everything here reports first and
# writes second: a command that touches $HOME has to be legible before clever.

# Official CLIs the kit wraps. `cursor-agent` is the unambiguous Cursor name:
# the Grok CLI also installs an `agent` entry, so Cursor is resolved through
# agentkit_cursor_bin (lib/common.sh), never via `command -v agent`.
AGENTKIT_CLIS=(claude codex cursor-agent opencode pi cline grok herdr)
AGENTKIT_WRAPPERS=(
  claudex claude-glm claudex-glm
  codexx codex-azure codex-xai codex-glm
  cursorx
  opencodex opencode-azure opencode-xai opencode-glm
  pix pi-azure pi-xai pi-glm
  clinex cline-azure cline-xai clinex-azure
  grokx
  agentbox
  agentkit
)
# This list must name every executable in the kit's bin/. tests/run.sh asserts
# that, because a hand-maintained list that silently under-reports a command is
# worse than no report at all.
AGENTKIT_ENV_KEYS=(ZAI_CODING_API_KEY XAI_API_KEY AZURE_OPENAI_API_KEY)

agentkit_env_file() {
  printf '%s' "${AGENTKIT_ENV:-${HOME}/.config/coding-agents-kit/env}"
}

agentkit_dest() {
  printf '%s' "${AGENTKIT_HOME:-${HOME}/.local/share/coding-agents-kit}"
}

agentkit_machines_file() {
  printf '%s' "${AGENTKIT_MACHINES:-${HOME}/.config/coding-agents-kit/machines.toml}"
}

agentkit_which() {
  command -v "$1" 2>/dev/null || true
}

# Path of an official CLI, with the Cursor-vs-Grok disambiguation applied.
agentkit_cli_path() {
  case "$1" in
    cursor-agent) agentkit_cursor_bin 2>/dev/null || true ;;
    *) agentkit_which "$1" ;;
  esac
}

# Shell rc files worth wiring, in the order we prefer them.
agentkit_rc_files() {
  local rc shell_rc=""
  case "$(basename "${SHELL:-}")" in
    zsh)  shell_rc="${HOME}/.zshrc" ;;
    bash) shell_rc="${HOME}/.bashrc" ;;
  esac
  for rc in "${shell_rc}" "${HOME}/.zshrc" "${HOME}/.bashrc" "${HOME}/.profile"; do
    [[ -n "${rc}" ]] && printf '%s\n' "${rc}"
  done | awk '!seen[$0]++'
}

agentkit_path_wired() {
  local rc
  while read -r rc; do
    [[ -f "${rc}" ]] || continue
    grep -Fq 'coding-agents-kit/bin' "${rc}" && return 0
  done < <(agentkit_rc_files)
  return 1
}

# Appends ONE guarded block, and only to rc files that already exist — except
# when none does, where the rc of the current shell is created. Never rewrites
# an existing line, so re-running the installer is free.
agentkit_ensure_path() {
  local path_line='export PATH="$HOME/.local/share/coding-agents-kit/bin:$HOME/.local/bin:$PATH"'
  local rc wrote=0 first=""
  while read -r rc; do
    [[ -n "${first}" ]] || first="${rc}"
    [[ -f "${rc}" ]] || continue
    if grep -Fq 'coding-agents-kit/bin' "${rc}"; then
      wrote=1
      continue
    fi
    printf '\n# coding-agents-setup-kit\n%s\n' "${path_line}" >> "${rc}"
    echo "PATH: appended to ${rc}"
    wrote=1
  done < <(agentkit_rc_files)
  if [[ "${wrote}" -eq 0 && -n "${first}" ]]; then
    touch "${first}"
    printf '\n# coding-agents-setup-kit\n%s\n' "${path_line}" >> "${first}"
    echo "PATH: created ${first} and appended the kit block"
  fi
}

# True when the env file has at least one uncommented KEY=value line.
agentkit_env_has_values() {
  local env_file
  env_file="$(agentkit_env_file)"
  [[ -f "${env_file}" ]] && grep -qE '^[A-Za-z_][A-Za-z0-9_]*=' "${env_file}"
}

agentkit_status() {
  local c w name path env_file dest grok_agent os
  dest="$(agentkit_dest)"
  env_file="$(agentkit_env_file)"
  os="$(agentkit_os)"

  echo "## Host"
  echo "os: ${os}	shell: ${SHELL:-unknown}"

  echo ""
  echo "## Prerequisites"
  for c in curl git node npm python3 docker ssh; do
    path="$(agentkit_which "${c}")"
    if [[ -n "${path}" ]]; then
      echo "tool ${c}: installed	${path}"
    else
      echo "tool ${c}: missing"
    fi
  done

  echo ""
  echo "## CLIs (official binaries)"
  for c in "${AGENTKIT_CLIS[@]}"; do
    path="$(agentkit_cli_path "${c}")"
    if [[ -n "${path}" ]]; then
      echo "cli ${c}: installed	${path}"
    else
      echo "cli ${c}: missing"
    fi
  done
  grok_agent="$(agentkit_which agent)"
  if [[ -n "${grok_agent}" ]] && ! agentkit_is_cursor_binary "${grok_agent}"; then
    echo "note: 'agent' on PATH (${grok_agent}) is the xAI Grok CLI, not Cursor — cursorx ignores it"
  fi

  echo ""
  echo "## Wrappers (this kit)"
  for w in "${AGENTKIT_WRAPPERS[@]}"; do
    path="$(agentkit_which "${w}")"
    if [[ -n "${path}" ]]; then
      echo "wrapper ${w}: on PATH	${path}"
    elif [[ -x "${dest}/bin/${w}" ]]; then
      echo "wrapper ${w}: installed, not on PATH	${dest}/bin/${w}"
    else
      echo "wrapper ${w}: missing"
    fi
  done

  echo ""
  echo "## Env"
  if [[ -f "${env_file}" ]]; then
    if agentkit_env_has_values; then
      echo "env file: present (values not shown)"
    else
      echo "env file: present but every line is commented — edit ${env_file} to enable keys"
    fi
  else
    echo "env file: missing"
  fi
  for name in "${AGENTKIT_ENV_KEYS[@]}"; do
    if [[ -n "${!name:-}" ]]; then
      echo "env ${name}: set"
    else
      echo "env ${name}: unset"
    fi
  done
  if [[ -n "${AZURE_OPENAI_RESOURCE:-}" || -n "${AZURE_OPENAI_BASE_URL:-}" ]]; then
    echo "env AZURE_OPENAI_RESOURCE/BASE_URL: set"
  else
    echo "env AZURE_OPENAI_RESOURCE/BASE_URL: unset"
  fi
  if [[ -f "${HOME}/.grok/auth.json" ]]; then
    echo "grok login: present (grokx works without XAI_API_KEY)"
  fi

  echo ""
  echo "## Machines"
  if [[ -f "$(agentkit_machines_file)" ]]; then
    echo "machines file: present	$(agentkit_machines_file)"
  else
    echo "machines file: none (optional — agentbox needs one; see machines.example.toml)"
  fi

  echo ""
  echo "## PATH"
  if agentkit_path_wired; then
    echo "shell rc: wired"
  else
    echo "shell rc: not wired"
  fi
  echo "kit dest: ${dest}"
  echo "kit bin on PATH: $(agentkit_which agentkit || echo no)"
}

agentkit_plan() {
  local c missing=() present=()
  echo ""
  echo "## Onboard plan"
  for c in "${AGENTKIT_CLIS[@]}"; do
    if [[ -n "$(agentkit_cli_path "${c}")" ]]; then
      present+=("${c}")
    else
      missing+=("${c}")
    fi
  done
  if [[ ${#present[@]} -gt 0 ]]; then
    echo "keep CLIs (already installed): ${present[*]}"
  else
    echo "keep CLIs (already installed): none"
  fi
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "install CLIs (missing): ${missing[*]}"
  else
    echo "install CLIs (missing): none"
  fi
  # These three are done by ./install.sh, not by `onboard`. Phrasing them as
  # things about to happen made a read-only run look like it had installed.
  echo "refresh wrappers: ./install.sh copies them (idempotent; removes no CLI)"
  if [[ -f "$(agentkit_env_file)" ]]; then
    echo "env file: present; ./install.sh keeps it (never overwrites)"
  else
    echo "env file: missing; ./install.sh creates it from env.example (names only)"
  fi
  if agentkit_path_wired; then
    echo "PATH: already wired"
  else
    echo "PATH: not wired; ./install.sh appends one guarded block to your shell rc"
  fi
}

# Prints the global-install command prefix for Node packages.
# npm first: it is what every one of these packages documents. pnpm only when
# `pnpm setup` was already run (otherwise `pnpm add -g` fails with
# ERR_PNPM_NO_GLOBAL_BIN_DIR). The kit never runs `pnpm setup` — it edits rc files.
agentkit_node_global_install() {
  if command -v npm >/dev/null 2>&1; then
    printf 'npm install -g'
  elif command -v pnpm >/dev/null 2>&1 && pnpm root -g >/dev/null 2>&1; then
    printf 'pnpm add -g'
  else
    return 1
  fi
}

# One line telling the human how to install Node on this OS. Never runs it:
# a package manager that needs sudo is the human's decision, not the kit's.
agentkit_node_hint() {
  case "$(agentkit_os)" in
    macos) echo "install Node: brew install node   (https://brew.sh)" ;;
    linux) echo "install Node: your distro's package manager (apt install nodejs npm / dnf install nodejs / pacman -S nodejs npm), or https://github.com/nvm-sh/nvm" ;;
    windows) echo "install Node: winget install OpenJS.NodeJS.LTS   (or https://nodejs.org)" ;;
    *) echo "install Node: https://nodejs.org" ;;
  esac
}

# Official vendor installers only. Nothing is uninstalled, moved or re-linked,
# and one failing installer never aborts the run.
agentkit_install_missing_clis() {
  local cursor_bin os
  os="$(agentkit_os)"

  if [[ -z "$(agentkit_which curl)" ]]; then
    echo "curl is missing and every vendor installer needs it — install curl first." >&2
    return 0
  fi
  if [[ -z "$(agentkit_which node)" ]]; then
    echo "node: missing — $(agentkit_node_hint)"
  fi

  if [[ -z "$(agentkit_which claude)" ]]; then
    echo "cli claude: installing..."
    curl -fsSL https://claude.ai/install.sh | bash || echo "cli claude: installer failed — see https://docs.claude.com/en/docs/claude-code"
  else
    echo "cli claude: already installed — skip"
  fi

  cursor_bin="$(agentkit_cursor_bin 2>/dev/null || true)"
  if [[ -z "${cursor_bin}" ]]; then
    echo "cli cursor-agent: installing..."
    if [[ -L "${HOME}/.local/bin/agent" || -e "${HOME}/.local/bin/agent" ]]; then
      echo "cli cursor-agent: note — Cursor's installer replaces ~/.local/bin/agent (currently Grok's); Grok stays reachable via ~/.grok/bin"
    fi
    curl -fsSL https://cursor.com/install | bash || echo "cli cursor-agent: installer failed — see https://cursor.com/docs/cli"
  else
    echo "cli cursor-agent: already installed — skip (${cursor_bin})"
  fi

  if [[ -z "$(agentkit_which opencode)" ]]; then
    echo "cli opencode: installing..."
    curl -fsSL https://opencode.ai/install | bash || echo "cli opencode: installer failed — see https://opencode.ai/docs"
  else
    echo "cli opencode: already installed — skip"
  fi

  if [[ -z "$(agentkit_which grok)" ]]; then
    echo "cli grok: installing (official xAI installer)..."
    curl -fsSL https://x.ai/cli/install.sh | bash || echo "cli grok: installer failed — see https://x.ai/cli"
  else
    echo "cli grok: already installed — skip"
  fi

  if [[ -z "$(agentkit_which herdr)" ]]; then
    echo "cli herdr: installing..."
    if ! curl -fsSL https://herdr.dev/install.sh | sh; then
      echo "cli herdr: installer failed — see https://herdr.dev/docs/install/"
    fi
  else
    echo "cli herdr: already installed — skip"
  fi

  local pm=""
  pm="$(agentkit_node_global_install || true)"
  if [[ -n "${pm}" ]]; then
    if [[ -z "$(agentkit_which codex)" ]]; then
      echo "cli codex: installing (${pm})..."
      ${pm} @openai/codex || echo "cli codex: install failed"
    else
      echo "cli codex: already installed — skip"
    fi
    if [[ -z "$(agentkit_which cline)" ]]; then
      echo "cli cline: installing (${pm})..."
      ${pm} cline || echo "cli cline: install failed"
    else
      echo "cli cline: already installed — skip"
    fi
    if [[ -z "$(agentkit_which pi)" ]]; then
      echo "cli pi: installing (${pm})..."
      ${pm} --ignore-scripts @earendil-works/pi-coding-agent || echo "cli pi: install failed"
    else
      echo "cli pi: already installed — skip"
    fi
  else
    echo "npm missing and pnpm has no global bin dir — skipping Codex/Cline/Pi ($(agentkit_node_hint))"
  fi
}


# ---------------------------------------------------------------------------
# Onboarding areas
#
# Selectable so a developer can run one thing, and so each area owns one
# concern with its own failure modes. Every area reports findings the same way
# and appends anything a human must decide to the closing checklist.
# ---------------------------------------------------------------------------

AGENTKIT_AREAS="clis machines herdr"
_AK_TODO=""

ak_todo() {
  _AK_TODO="${_AK_TODO}
  - $1
    -> $2"
}

ak_ok()   { printf '  ok      %s\n' "$1"; }
ak_note() { printf '  note    %s\n' "$1"; }
ak_gap()  { printf '  MISSING %s\n' "$1"; }

ak_kit_bin() {
  printf '%s' "$(cd "$(dirname "${BASH_SOURCE[0]}")/../bin" 2>/dev/null && pwd)"
}

# --- area: clis and wrappers ------------------------------------------------
agentkit_area_clis() {
  local install_clis="${1:-0}"
  echo "## area: clis and wrappers"
  agentkit_status
  agentkit_plan
  if [ "$install_clis" = "1" ]; then
    agentkit_install_missing_clis
  fi

  # `onboard` reports; `install.sh` writes. Without these, a machine with no env
  # file and no PATH wiring reached "nothing left to do", which is the one line a
  # newcomer reads to decide they are finished.
  local envf
  envf="$(agentkit_env_file)"
  if [[ ! -f "${envf}" ]]; then
    ak_todo "no env file yet, so provider wrappers have nothing to read" \
            "run ./install.sh from the kit (it creates ${envf} with names only)"
  fi
  if ! agentkit_path_wired; then
    ak_todo "the kit's bin directory is not on your PATH" \
            "run ./install.sh from the kit, then open a new shell"
  fi
}

# --- area: machines (optional; only when you declared some) -----------------
agentkit_area_machines() {
  echo "## area: machines"
  local bin conf count
  bin="$(ak_kit_bin)"
  conf="$(agentkit_machines_file)"

  if [ ! -f "$conf" ]; then
    ak_note "no machines file at ${conf} — nothing to reconcile"
    ak_note "optional: copy machines.example.toml there to manage containers/VMs with agentbox"
    return 0
  fi
  if [ ! -x "${bin}/agentbox" ]; then
    ak_gap "agentbox is not in this kit checkout"
    ak_todo "the machines command is missing" "re-run ./install.sh from the kit"
    return 0
  fi

  count="$("${bin}/agentbox" ls --json 2>/dev/null | grep -c '"name"' || true)"
  if [ "${count:-0}" -eq 0 ]; then
    ak_gap "no machine could be read from ${conf}"
    ak_todo "the machines file defines nothing usable" "check the [[machine]] blocks against machines.example.toml"
    return 0
  fi
  ak_ok "${count} machine(s) declared in ${conf}"
  "${bin}/agentbox" doctor || true
  return 0
}

# --- area: herdr ------------------------------------------------------------
agentkit_area_herdr() {
  echo "## area: herdr"
  if ! command -v herdr >/dev/null 2>&1; then
    ak_gap "herdr is not installed"
    ak_todo "Herdr is optional but this kit documents it heavily" \
            "install it with: curl -fsSL https://herdr.dev/install.sh | sh   (or ./install.sh --clis)"
    return 0
  fi
  ak_ok "herdr installed ($(herdr --version 2>/dev/null | head -1))"

  local lib
  lib="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=/dev/null
  [ -f "${lib}/herdr.sh" ] && . "${lib}/herdr.sh"

  local machines
  machines="$(herdr machine list --json 2>/dev/null | grep -c '"target"' || true)"
  ak_note "${machines:-0} saved machine(s) in the Herdr catalog"

  # Integrations are the one Herdr feature that edits the agent's own config, so
  # the kit reports and never installs.
  if herdr integration status >/dev/null 2>&1; then
    ak_note "run 'herdr integration status' to see which agents report lifecycle/session state"
    ak_todo "native session restore is per-agent and edits that agent's config" \
            "install the ones you use yourself: herdr integration install claude|codex|cursor|opencode|pi|grok"
  fi
  return 0
}

# --- the runner -------------------------------------------------------------
agentkit_onboard() {
  local install_clis=0 areas="" a
  while [ $# -gt 0 ]; do
    case "$1" in
      --clis) install_clis=1 ;;
      --no-clis) install_clis=0 ;;
      *) areas="${areas} $1" ;;
    esac
    shift
  done
  [ -n "${areas// /}" ] || areas="$AGENTKIT_AREAS"

  for a in $areas; do
    case " $AGENTKIT_AREAS " in
      *" $a "*) ;;
      *) printf 'agentkit: unknown area %s — valid areas: %s\n' "$a" "$AGENTKIT_AREAS" >&2; return 2 ;;
    esac
  done

  _AK_TODO=""
  for a in $areas; do
    case "$a" in
      clis)     agentkit_area_clis "$install_clis" ;;
      machines) agentkit_area_machines ;;
      herdr)    agentkit_area_herdr ;;
    esac
    echo ""
  done

  # The last lines answer "am I set up?" without reading the rest.
  echo "## what is left"
  if [ -z "$_AK_TODO" ]; then
    echo "  nothing — this machine is set up."
  else
    printf '%s\n' "$_AK_TODO"
  fi
}

agentkit_copy_wrappers() {
  local src="$1"
  local dest
  dest="$(agentkit_dest)"
  mkdir -p "${dest}/bin" "${dest}/lib" "$(dirname "$(agentkit_env_file)")" "${HOME}/.local/bin"
  cp -R "${src}/lib/." "${dest}/lib/"
  cp -R "${src}/bin/." "${dest}/bin/"
  rm -rf "${dest}/lib/__pycache__" "${dest}/bin/"*.md "${dest}/lib/"*.md
  chmod +x "${dest}/bin/"* "${dest}/lib/"*.sh 2>/dev/null || true
  echo "wrappers: refreshed in ${dest}/bin"
}

agentkit_ensure_env() {
  local env_file src_example
  env_file="$(agentkit_env_file)"
  src_example="$1"
  mkdir -p "$(dirname "${env_file}")"
  if [[ -f "${env_file}" ]]; then
    chmod 600 "${env_file}" 2>/dev/null || true
    echo "env file: kept ${env_file} (not overwritten)"
    return 0
  fi
  cp "${src_example}" "${env_file}"
  chmod 600 "${env_file}"
  echo "env file: created ${env_file} from env.example — fill your keys there, locally"
}
