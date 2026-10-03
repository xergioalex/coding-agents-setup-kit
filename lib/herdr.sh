#!/usr/bin/env bash
#
# herdr.sh — resolve Herdr saved machines from a repository's SSH alias.
#
# The join key is Herdr's `target` field, which IS the SSH alias the host
# command already maps per repository. So a machine id is resolved at runtime and
# nobody maintains a mapping table.
#
# Degradation contract (see the plan's analysis_results/HERDR_CONTRACT.md):
# every function here succeeds when Herdr is unavailable, unknown or silent.
# Nothing in this file may change a caller's exit code. Verified against
# herdr 0.9.0.

# One warning per process, not one per machine — which only holds if callers
# stay in the current shell. `id="$(herdr_kit_machine_id …)"` runs the lookup in
# a subshell, where both this flag and the cache below are discarded, so the
# in-shell entry point is herdr_kit_resolve and the printing wrappers exist for
# tests and for a caller that genuinely wants a string.
_HERDR_KIT_WARNED="${_HERDR_KIT_WARNED:-0}"
# `herdr machine list --json` is called at most once and the result reused.
_HERDR_KIT_JSON=""
_HERDR_KIT_JSON_LOADED=0
# Set by herdr_kit_resolve, in the caller's own shell.
_HERDR_KIT_ID=""
_HERDR_KIT_ENABLED=""

herdr_kit_warn() {
  [ "$_HERDR_KIT_WARNED" = "1" ] && return 0
  _HERDR_KIT_WARNED=1
  printf 'dev: herdr — %s\n' "$*" >&2
  return 0
}

# Outcome 1: herdr is not installed.
herdr_kit_available() {
  command -v herdr >/dev/null 2>&1
}

# Reads the catalog once. Never fails: an error leaves the cache empty.
herdr_kit_load() {
  [ "$_HERDR_KIT_JSON_LOADED" = "1" ] && return 0
  _HERDR_KIT_JSON_LOADED=1
  if ! herdr_kit_available; then
    return 0
  fi
  _HERDR_KIT_JSON="$(herdr machine list --json 2>/dev/null || true)"
  if [ -z "$_HERDR_KIT_JSON" ]; then
    herdr_kit_warn "could not read the machine list; skipping"
  fi
  return 0
}

# herdr_kit_resolve <ssh_target>
# Sets _HERDR_KIT_ID and _HERDR_KIT_ENABLED in the CALLER's shell, so the cache
# and the warn-once flag survive. Always returns 0.
herdr_kit_resolve() {
  local target="$1" out
  _HERDR_KIT_ID=""; _HERDR_KIT_ENABLED=""
  [ -n "$target" ] || return 0
  herdr_kit_load
  [ -n "$_HERDR_KIT_JSON" ] || return 0
  out="$(herdr_kit_query "$target")"
  [ -n "$out" ] || return 0
  _HERDR_KIT_ID="${out%% *}"
  _HERDR_KIT_ENABLED="${out##* }"
  return 0
}

# herdr_kit_machine_for <ssh_target>
# Prints "<id> <enabled>" when a machine matches, nothing otherwise. Always 0.
herdr_kit_machine_for() {
  herdr_kit_resolve "$1"
  [ -n "$_HERDR_KIT_ID" ] && printf '%s %s\n' "$_HERDR_KIT_ID" "$_HERDR_KIT_ENABLED"
  return 0
}

# A working Python 3, resolved once. Self-contained on purpose (this file is
# sourced alone): the Windows Microsoft Store alias answers `python3` but runs
# nothing, so a candidate counts only once it reports a Python 3 version.
_HERDR_KIT_PY=""
herdr_kit_python() {
  if [ -z "$_HERDR_KIT_PY" ]; then
    local c
    for c in python3 python "py -3"; do
      # shellcheck disable=SC2086 # "py -3" is two words on purpose
      case "$($c --version 2>&1)" in "Python 3"*) _HERDR_KIT_PY="$c"; break ;; esac
    done
    [ -n "$_HERDR_KIT_PY" ] || return 1
  fi
  # shellcheck disable=SC2086
  $_HERDR_KIT_PY "$@"
}

# The parse itself. Reads the cached JSON; never fails.
herdr_kit_query() {
  local target="$1"
  printf '%s' "$_HERDR_KIT_JSON" | herdr_kit_python -c '
import json, sys
target = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(0)
if not isinstance(data, list):
    raise SystemExit(0)
for m in data:
    if isinstance(m, dict) and m.get("target") == target:
        print("%s %s" % (m.get("id", ""), "true" if m.get("enabled") else "false"))
        break
' "$target" 2>/dev/null || true
  return 0
}

# herdr_kit_machine_id <ssh_target>  -> just the id, or nothing.
herdr_kit_machine_id() {
  herdr_kit_resolve "$1"
  printf '%s' "$_HERDR_KIT_ID"
  return 0
}

# herdr_kit_set_state <ssh_target> enable|disable
# Best effort by contract: a failure warns once and still returns 0.
herdr_kit_set_state() {
  local target="$1" action="$2" id
  if ! herdr_kit_available; then
    herdr_kit_warn "not installed; leaving machines alone"
    return 0
  fi
  herdr_kit_resolve "$target"        # in this shell: the cache is reused
  id="$_HERDR_KIT_ID"
  if [ -z "$id" ]; then
    return 0                    # no machine yet is a normal state, not an error
  fi
  if herdr machine "$action" "$id" >/dev/null 2>&1; then
    printf 'herdr: machine %s %sd\n' "$target" "$action"
  else
    herdr_kit_warn "could not $action machine $target; continuing"
  fi
  return 0
}

# herdr_kit_ssh_alias_defined <ssh_target>
# True when ~/.ssh/config (or an include it pulls in) resolves the alias.
herdr_kit_ssh_alias_defined() {
  local target="$1"
  [ -n "$target" ] || return 1
  ssh -G "$target" 2>/dev/null | awk -v t="$target" '
    $1 == "hostname" { host = $2 }
    END { exit (host == "" || host == t) ? 1 : 0 }
  '
}
