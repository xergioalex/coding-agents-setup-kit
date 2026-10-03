#!/usr/bin/env bash
# Host-vs-container detection for coding-agents-setup-kit.
#
# Deliberately side-effect free: it defines two functions and nothing else — no
# env file is read, no variable is exported. `bin/agentbox` sources this alone
# precisely because sourcing common.sh would export the developer's env file and
# could change how the machines file is resolved.

# This kit installs commands into the developer's $HOME, drives Docker Compose,
# writes SSH config and moves Herdr machines. A container can do none of those
# for its host, so the commands that do them refuse to run inside one rather
# than half-working against the container's own filesystem.
#
# A WSL shell is NOT a container: it has its own $HOME and its own PATH, and the
# kit installs into it normally. What a WSL shell must not do is claim to report
# the Windows side's state — the docs say so, the code does not need to.

agentkit_in_container() {
  [[ -f /.dockerenv ]] && return 0
  [[ -n "${REMOTE_CONTAINERS:-}" ]] && return 0
  [[ -n "${CODESPACES:-}" ]] && return 0
  [[ -n "${DEVCONTAINER:-}" ]] && return 0
  [[ "${container:-}" == "docker" || "${container:-}" == "podman" ]] && return 0
  grep -qa 'docker\|containerd\|kubepods' /proc/1/cgroup 2>/dev/null && return 0
  return 1
}

# Print why the caller cannot continue and how to get to a host shell. The
# command name is the caller's, so the message names the thing the developer
# actually typed.
agentkit_container_refusal() {
  local cmd="${1:-agentkit}"
  printf '%s: this runs on the host machine itself, and this shell is inside a container.\n' "$cmd" >&2
  printf '  Docker, your SSH config and Herdr all live on the host; a container\n' >&2
  printf '  cannot reach them.\n' >&2
  printf '  Open a shell on the Mac and run it there:\n' >&2
  printf '    VS Code / Cursor:  Dev Containers: Reopen Folder Locally\n' >&2
  printf '    or just open a new Terminal window on the Mac.\n' >&2
}

# Refuse when inside a container. Callers: `command || exit 1`.
agentkit_require_host() {
  agentkit_in_container || return 0
  agentkit_container_refusal "${1:-agentkit}"
  return 1
}


# Print the command that runs a working Python 3 ("python3", "python" or
# "py -3"); return 1 when there is none. On Windows the Microsoft Store alias
# answers `python3` but runs nothing, so a candidate counts only once it reports
# a Python 3 version. Callers split the words: `read -ra py <<<"$(agentkit_python)"`.
agentkit_python() {
  local c
  for c in python3 python; do
    command -v "${c}" >/dev/null 2>&1 || continue
    case "$("${c}" --version 2>&1)" in "Python 3"*) printf '%s' "${c}"; return 0 ;; esac
  done
  if command -v py >/dev/null 2>&1; then
    case "$(py -3 --version 2>&1)" in "Python 3"*) printf 'py -3'; return 0 ;; esac
  fi
  return 1
}
