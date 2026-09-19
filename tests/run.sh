#!/usr/bin/env bash
# Validation gate for coding-agents-setup-kit.
#
# Everything runs against a throwaway HOME under tmp/ — the suite never reads or
# writes the real ~/.config, ~/.codex, ~/.pi, ~/.ssh or your shell rc, never
# installs a CLI, and never touches the network.
#
# Usage: tests/run.sh [all|lint|writers|resolver|herdr|machines|onboard|status|win]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCOPE="${1:-all}"
FAILS=0
PASSES=0

pass() { PASSES=$((PASSES + 1)); printf '  ok   %s\n' "$1"; }
fail() { FAILS=$((FAILS + 1)); printf '  FAIL %s\n' "$1"; }
check() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "${name}"; else fail "${name}"; fi
}

mkdir -p "${ROOT}/tmp"
SANDBOX="$(mktemp -d "${ROOT}/tmp/test-home.XXXXXX")"
trap 'rm -rf "${SANDBOX}"' EXIT

# Runs the lint scope from / in a child process; the guard env var stops that
# child from recursing back into this check.
lint_from_elsewhere() {
  local out
  out="$(cd / && KIT_TESTS_NESTED=1 bash "${ROOT}/tests/run.sh" lint)" || return 1
  printf '%s\n' "${out}" | grep -qE '^  ok   bash -n lib/[A-Za-z_]+\.sh$'
}

run_lint() {
  echo "## lint"
  local f
  for f in "${ROOT}/install.sh" "${ROOT}"/lib/*.sh "${ROOT}"/bin/* "${ROOT}/tests/run.sh"; do
    [[ "${f}" == *.md ]] && continue
    check "bash -n ${f#"${ROOT}/"}" bash -n "${f}"
  done
  check "python3 -m py_compile lib/*.py" python3 -m py_compile "${ROOT}"/lib/*.py
  rm -rf "${ROOT}/lib/__pycache__"
  # The gate is documented as tests/run.sh and may be run from anywhere, so
  # prove the globs above do not silently collapse when cwd is somewhere else.
  if [ -z "${KIT_TESTS_NESTED:-}" ]; then
    check "lint expands the same from another directory" lint_from_elsewhere
  fi
  if command -v shellcheck >/dev/null 2>&1; then
    local -a scripts=("${ROOT}/install.sh" "${ROOT}/tests/run.sh")
    for f in "${ROOT}"/lib/*.sh "${ROOT}"/bin/*; do [[ "${f}" == *.md ]] || scripts+=("${f}"); done
    check "shellcheck -S warning (install.sh lib bin tests)" shellcheck -S warning "${scripts[@]}"
  else
    echo "  skip shellcheck (not installed: brew install shellcheck / apt install shellcheck)"
  fi

  # No key-shaped string may ever be committed, in any tracked file.
  if grep -rEn '(sk-[A-Za-z0-9_-]{20,}|xai-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,})' \
      "${ROOT}/bin" "${ROOT}/lib" "${ROOT}/win" "${ROOT}/install.sh" "${ROOT}/install.ps1" \
      "${ROOT}/env.example" "${ROOT}/docs" >/dev/null 2>&1; then
    fail "no secret-looking strings in the kit"
  else
    pass "no secret-looking strings in the kit"
  fi

  # This kit is generic on purpose: no employer, no internal host, no private
  # repo, no personal machine. Extend the marker list when you find a new way to
  # leak one; it is cheaper than reviewing every doc by hand.
  if grep -rIniE "${AGENTKIT_PRIVATE_MARKERS:-internal-only|corp\.local|\.intranet|\.internal[/: ]}" \
      "${ROOT}/bin" "${ROOT}/lib" "${ROOT}/win" "${ROOT}/docs" "${ROOT}/install.sh" \
      "${ROOT}/install.ps1" "${ROOT}/env.example" "${ROOT}"/*.md >/dev/null 2>&1; then
    fail "no company-specific references in the kit"
  else
    pass "no company-specific references in the kit"
  fi

  # The installer strips *.md from the PATH directory, so markdown there would
  # be silently dropped — and bin/* globs would try to execute it.
  local stray=0
  for f in "${ROOT}"/bin/*.md "${ROOT}"/lib/*.md; do
    [[ -e "${f}" ]] || continue
    [[ "$(basename "${f}")" == "README.md" ]] || stray=1
  done
  if [[ "${stray}" -eq 0 ]]; then pass "no markdown in bin/ or lib/ except README.md"; else fail "stray markdown in bin/ or lib/"; fi

  # Every executable in bin/ must be reported by the doctor.
  local listed disk
  listed="$(bash -c "source '${ROOT}/lib/onboard.sh' >/dev/null 2>&1; printf '%s\n' \"\${AGENTKIT_WRAPPERS[@]}\"" | sort)"
  disk="$(for f in "${ROOT}"/bin/*; do b="$(basename "${f}")"; [[ "${b}" == *.md ]] || echo "${b}"; done | sort)"
  if [[ "${listed}" == "${disk}" ]]; then
    pass "the doctor's wrapper list matches bin/"
  else
    fail "the doctor's wrapper list differs from bin/: $(diff <(echo "${listed}") <(echo "${disk}") | tr '\n' ' ')"
  fi
}

run_writers() {
  echo "## config writers (sandbox: ${SANDBOX})"
  local w="${SANDBOX}/writers"; mkdir -p "${w}"

  # OpenCode: merge one provider, keep everything else, never set the global model
  printf '{"provider":{"ollama":{"options":{"baseURL":"http://127.0.0.1:11434/v1"}}},"model":"ollama/x","theme":"dark"}\n' > "${w}/opencode.json"
  check "opencode writer runs" python3 "${ROOT}/lib/write_opencode_provider.py" "${w}/opencode.json" xai XAI_API_KEY https://api.x.ai/v1 grok-code-fast-1 grok-4
  check "opencode writer keeps other providers + global model + extra keys" python3 - "${w}/opencode.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
assert "ollama" in d["provider"], "ollama dropped"
assert d["model"] == "ollama/x", "global model rewritten"
assert d["theme"] == "dark", "unrelated key dropped"
p = d["provider"]["xai"]
assert p["options"]["apiKey"] == "{env:XAI_API_KEY}", p
assert p["whitelist"] == ["grok-code-fast-1", "grok-4"], p["whitelist"]
PYEOF
  check "opencode writer keeps a one-time backup" test -f "${w}/opencode.json.agentkit.bak"
  check "opencode writer is idempotent" python3 "${ROOT}/lib/write_opencode_provider.py" "${w}/opencode.json" xai XAI_API_KEY https://api.x.ai/v1 grok-code-fast-1 grok-4
  printf '{not json' > "${w}/broken.json"
  if python3 "${ROOT}/lib/write_opencode_provider.py" "${w}/broken.json" xai XAI_API_KEY u m >/dev/null 2>&1; then
    fail "opencode writer refuses invalid JSON"
  elif [[ "$(cat "${w}/broken.json")" == "{not json" ]]; then
    pass "opencode writer refuses invalid JSON and leaves the file untouched"
  else
    fail "opencode writer overwrote an invalid file"
  fi

  # Pi: provider upsert with an env reference, models deduped
  check "pi writer runs" python3 "${ROOT}/lib/write_pi_provider.py" "${w}/models.json" zai-glm https://api.z.ai/api/coding/paas/v4 ZAI_CODING_API_KEY 200000 131072 false glm-4.6:sonnet glm-4.6:opus glm-4.5-air:haiku
  check "pi writer stores an env reference and dedups models" python3 - "${w}/models.json" <<'PYEOF'
import json, sys
p = json.load(open(sys.argv[1]))["providers"]["zai-glm"]
assert p["apiKey"] == "$ZAI_CODING_API_KEY", p["apiKey"]
assert [m["id"] for m in p["models"]] == ["glm-4.6", "glm-4.5-air"], p["models"]
assert p["compat"]["supportsReasoningEffort"] is False
PYEOF
  check "pi writer merges a second provider" python3 "${ROOT}/lib/write_pi_provider.py" "${w}/models.json" xai-grok https://api.x.ai/v1 XAI_API_KEY 200000 32768 true grok-code-fast-1:daily
  check "pi writer kept the first provider" python3 -c "import json,sys; d=json.load(open(sys.argv[1]))['providers']; assert set(d)=={'zai-glm','xai-grok'}" "${w}/models.json"

  # Codex: profile overlay that references env_key and never a value
  check "codex profile writer runs" python3 "${ROOT}/lib/write_codex_profile.py" "${w}/azure.config.toml" azure "Azure OpenAI" https://example.services.ai.azure.com/openai/v1 AZURE_OPENAI_API_KEY my-deployment
  check "codex profile references env_key, never a value" bash -c "grep -q 'env_key = \"AZURE_OPENAI_API_KEY\"' '${w}/azure.config.toml' && ! grep -qi 'api_key *= *\"[^\"]' '${w}/azure.config.toml'"

  # No writer may ever put a key value on disk.
  printf 'secret-shaped-value\n' > "${w}/.probe"
  if grep -rq 'secret-shaped-value' "${w}"/*.json "${w}"/*.toml 2>/dev/null; then
    fail "a writer stored a raw value"
  else
    pass "no writer stored a raw value"
  fi
}

run_resolver() {
  echo "## cursor-vs-grok resolver"
  local fake="${SANDBOX}/fakebin"; mkdir -p "${fake}"
  printf '#!/bin/sh\necho "grok 1.0.30 (fake) [stable]"\n' > "${fake}/agent"; chmod +x "${fake}/agent"
  local out
  # Restricted PATH: the host may have a real cursor-agent installed; the test must not see it.
  out="$(cd "${ROOT}" && PATH="${fake}:/usr/bin:/bin" HOME="${SANDBOX}" bash -c 'source lib/common.sh; agentkit_cursor_bin' 2>/dev/null || true)"
  if [[ -z "${out}" ]]; then pass "a grok-branded agent is not reported as Cursor"; else fail "grok-branded agent reported as Cursor: ${out}"; fi

  local cv="${SANDBOX}/.local/share/cursor-agent/versions/2026.01.01-test"; mkdir -p "${cv}" "${SANDBOX}/.local/bin"
  printf '#!/bin/sh\ncase "$1" in --version) echo "2026.01.01-test";; *) echo "Cursor Agent CLI args: $*";; esac\n' > "${cv}/cursor-agent"; chmod +x "${cv}/cursor-agent"
  ln -sfn "${cv}/cursor-agent" "${SANDBOX}/.local/bin/cursor-agent"
  out="$(cd "${ROOT}" && PATH="${SANDBOX}/.local/bin:${fake}:${PATH}" HOME="${SANDBOX}" bash -c 'source lib/common.sh; agentkit_cursor_bin' 2>/dev/null || true)"
  if [[ "${out}" == "${SANDBOX}/.local/bin/cursor-agent" ]]; then pass "cursor-agent on PATH wins over a grok agent"; else fail "cursor-agent not resolved (got: ${out})"; fi

  out="$(cd "${ROOT}" && PATH="${fake}:/usr/bin:/bin" HOME="${SANDBOX}" bash -c 'source lib/common.sh; agentkit_cursor_bin' 2>/dev/null || true)"
  if [[ "${out}" == "${cv}/cursor-agent" ]]; then pass "falls back to the cursor-agent versions dir when PATH is shadowed"; else fail "version-dir fallback failed (got: ${out})"; fi

  out="$(cd "${ROOT}" && PATH="${fake}:/usr/bin:/bin" HOME="${SANDBOX}" bash bin/cursorx 2>&1 || true)"
  case "${out}" in *"Cursor Agent CLI args: --force"*) pass "cursorx execs the Cursor binary with --force (never grok)";; *) fail "cursorx output unexpected: ${out}";; esac
}

run_herdr() {
  echo "## herdr resolver (stubbed herdr — the suite never needs a real one)"
  local stub="${SANDBOX}/stubbin"
  mkdir -p "${stub}"
  # The payload is planted in the id, the label and the target: the id is what
  # reaches `herdr machine <action> <id>`, so it is the argument that matters.
  local pwned="${SANDBOX}/kit-pwned"
  {
    echo '#!/bin/sh'
    echo 'if [ "$1" = "machine" ] && [ "$2" = "list" ]; then'
    printf "  cat <<'JSON'\n"
    printf '[{"id":"aaa111","label":"Dev box","target":"devbox","session":"default","enabled":true},\n'
    # No spaces in the payload: the resolver splits fields on space, so a payload
    # containing one would be destroyed before reaching anything and the check
    # would pass for the wrong reason. ${IFS} keeps it space-free.
    printf ' {"id":"b;$(touch${IFS}%s.id)","label":"W;$(touch${IFS}%s.label)","target":"hostile","session":"default","enabled":false}]\n' \
      "${pwned}" "${pwned}"
    printf 'JSON\n'
    echo '  exit 0'
    echo 'fi'
    echo 'exit 0'
  } > "${stub}/herdr"
  chmod +x "${stub}/herdr"

  local out
  out="$(PATH="${stub}:${PATH}" bash -c ". '${ROOT}/lib/herdr.sh'; herdr_kit_machine_id devbox" 2>/dev/null)"
  if [ "${out}" = "aaa111" ]; then pass "resolver maps a known target to its id"; else fail "resolver did not map a known target (got '${out}')"; fi

  if PATH="${stub}:${PATH}" bash -c ". '${ROOT}/lib/herdr.sh'; herdr_kit_machine_id nope" >/dev/null 2>&1; then
    pass "unknown target resolves to nothing and succeeds"
  else
    fail "unknown target made the resolver fail"
  fi

  if env -i PATH=/usr/bin:/bin HOME="${SANDBOX}" bash -c ". '${ROOT}/lib/herdr.sh'; herdr_kit_machine_id devbox" >/dev/null 2>&1; then
    pass "resolver succeeds with no herdr installed"
  else
    fail "resolver failed when herdr was absent"
  fi

  rm -f "${pwned}".*
  PATH="${stub}:${PATH}" bash -c ". '${ROOT}/lib/herdr.sh'; herdr_kit_machine_for hostile" >/dev/null 2>&1 || true
  PATH="${stub}:${PATH}" bash -c ". '${ROOT}/lib/herdr.sh'; herdr_kit_set_state hostile disable" >/dev/null 2>&1 || true
  if ls "${pwned}".* >/dev/null 2>&1; then
    fail "a hostile machine label, id or target executed"
  else
    pass "a hostile machine label, id or target never executes"
  fi
  rm -f "${pwned}".*

  # Python side: agentbox parses the same catalog, and must be just as safe.
  out="$(PATH="${stub}:${PATH}" python3 -c "
import sys; sys.path.insert(0, '${ROOT}/lib')
import agentbox
m = agentbox.herdr_machine_for('hostile')
print(m['id'] if m else 'none')
" 2>/dev/null || true)"
  if ls "${pwned}".* >/dev/null 2>&1; then
    fail "agentbox executed a hostile machine id"
  else
    pass "agentbox never executes a hostile machine id"
  fi
}

run_machines() {
  echo "## agentbox (machines)"
  local conf="${SANDBOX}/machines.toml"
  cat > "${conf}" <<'TOML'
# a comment
[[machine]]
name    = "devbox"
ssh     = "devbox"
label   = "Dev box"
compose = "/nonexistent/docker-compose.yml"
service = "devbox"
host    = "127.0.0.1"
port    = 22029
user    = "dev"

[[machine]]
name = "buildserver"
TOML

  check "agentbox --help works anywhere" bash "${ROOT}/bin/agentbox" --help
  local out
  out="$(AGENTKIT_MACHINES="${conf}" bash "${ROOT}/bin/agentbox" ls --json 2>/dev/null)"
  if python3 -c "
import json,sys
d = json.loads(sys.argv[1])
assert [m['name'] for m in d] == ['devbox','buildserver'], d
assert d[1]['ssh'] == 'buildserver', 'ssh should default to name'
assert d[1]['label'] == 'buildserver', 'label should default to name'
assert d[0]['port'] == 22029, d[0]
" "${out}" 2>/dev/null; then
    pass "machines file parses, defaults applied"
  else
    fail "machines file did not parse as expected"
  fi

  out="$(AGENTKIT_MACHINES="${conf}" bash "${ROOT}/bin/agentbox" ssh-config 2>/dev/null)"
  if grep -q '^Host devbox' <<<"${out}" && grep -q 'HostName 127.0.0.1' <<<"${out}" && grep -q 'Port 22029' <<<"${out}"; then
    pass "ssh-config renders a Host block from the machines file"
  else
    fail "ssh-config output unexpected"
  fi
  if grep -q 'buildserver' <<<"${out}"; then
    fail "ssh-config invented a block for a machine with no port"
  else
    pass "ssh-config skips a machine that declares no port"
  fi

  # An unknown name must fail loudly, not silently act on the wrong machine.
  if AGENTKIT_MACHINES="${conf}" bash "${ROOT}/bin/agentbox" status nope >/dev/null 2>&1; then
    fail "an unknown machine name exited 0"
  else
    pass "an unknown machine name exits non-zero"
  fi

  # A broken config is reported, never half-understood.
  printf '[[server]]\nname = "x"\n' > "${SANDBOX}/bad.toml"
  if AGENTKIT_MACHINES="${SANDBOX}/bad.toml" bash "${ROOT}/bin/agentbox" ls --json >/dev/null 2>&1; then
    fail "an unsupported table was accepted"
  else
    pass "an unsupported table is refused with an error"
  fi

  # No machines file at all is a normal state for `ls`, not an error.
  if AGENTKIT_MACHINES="${SANDBOX}/none.toml" bash "${ROOT}/bin/agentbox" ls >/dev/null 2>&1; then
    pass "ls with no machines file succeeds"
  else
    fail "ls with no machines file failed"
  fi

  # The Herdr half degrades: no herdr installed must not change the exit code.
  out="$(env -i PATH=/usr/bin:/bin HOME="${SANDBOX}" AGENTKIT_MACHINES="${conf}" \
        bash "${ROOT}/bin/agentbox" doctor 2>&1 || echo "EXIT-NONZERO")"
  if grep -q 'EXIT-NONZERO' <<<"${out}"; then
    fail "doctor failed when herdr was absent"
  else
    pass "doctor succeeds when herdr is absent (warn once, never fail the caller)"
  fi

  # ssh-config --write must refuse a file it did not generate.
  local include="${SANDBOX}/ssh-include"
  printf 'Host mine\n  HostName 10.0.0.1\n' > "${include}"
  if AGENTKIT_MACHINES="${conf}" AGENTKIT_SSH_INCLUDE="${include}" \
     bash "${ROOT}/bin/agentbox" ssh-config --write >/dev/null 2>&1; then
    fail "ssh-config --write clobbered a file it did not generate"
  elif grep -q 'HostName 10.0.0.1' "${include}"; then
    pass "ssh-config --write refuses a file it did not generate"
  else
    fail "ssh-config --write destroyed an unmanaged file"
  fi

  # Lifecycle verbs drive Docker and Herdr: they belong to the host machine.
  out="$(HOME="${SANDBOX}" REMOTE_CONTAINERS=true AGENTKIT_MACHINES="${conf}" \
        bash "${ROOT}/bin/agentbox" up devbox 2>&1 || true)"
  if grep -q 'inside a container' <<<"${out}"; then
    pass "agentbox up refuses inside a container"
  else
    fail "agentbox up did not refuse inside a container"
  fi
}

run_onboard() {
  echo "## onboarding (sandbox HOME)"
  local home="${SANDBOX}/onboardhome"; mkdir -p "${home}"
  local envf="${home}/env"
  local out

  out="$(cd "${ROOT}" && HOME="${home}" AGENTKIT_ENV="${envf}" AGENTKIT_HOME="${home}/kit" \
        bash bin/agentkit onboard clis 2>&1 || true)"
  if grep -q 'dummy' <<<"${out}"; then fail "onboard printed something that looks like a value"; else pass "onboard prints no values"; fi
  if grep -q '## what is left' <<<"${out}"; then pass "onboard ends with the checklist"; else fail "onboard checklist missing"; fi
  if [[ -f "${home}/.ssh/config" ]]; then fail "onboard wrote ~/.ssh/config"; else pass "onboard never writes ~/.ssh/config"; fi

  # An unknown area is a usage error, not a silent no-op.
  if (cd "${ROOT}" && HOME="${home}" bash bin/agentkit onboard not-an-area) >/dev/null 2>&1; then
    fail "an unknown onboarding area exited 0"
  else
    pass "an unknown onboarding area exits non-zero"
  fi

  # install.sh: the env file is created once and then never overwritten.
  local ihome="${SANDBOX}/installhome"; mkdir -p "${ihome}"
  (cd "${ROOT}" && HOME="${ihome}" AGENTKIT_ENV="${ihome}/env" AGENTKIT_HOME="${ihome}/kit" \
    bash install.sh --no-path >/dev/null 2>&1) || true
  if [[ -f "${ihome}/env" ]]; then pass "install.sh creates the env file"; else fail "install.sh did not create the env file"; fi
  printf 'XAI_API_KEY=mine\n' > "${ihome}/env"
  (cd "${ROOT}" && HOME="${ihome}" AGENTKIT_ENV="${ihome}/env" AGENTKIT_HOME="${ihome}/kit" \
    bash install.sh --no-path >/dev/null 2>&1) || true
  if grep -q '^XAI_API_KEY=mine$' "${ihome}/env"; then
    pass "install.sh never overwrites an existing env file"
  else
    fail "install.sh overwrote the env file"
  fi
  if [[ -x "${ihome}/kit/bin/claudex" ]]; then pass "install.sh installs the wrappers"; else fail "install.sh did not install the wrappers"; fi
  if [[ -e "${ihome}/kit/bin/README.md" ]]; then fail "install.sh copied markdown into the PATH dir"; else pass "install.sh strips markdown from the PATH dir"; fi

  # PATH wiring is idempotent and appends exactly one block.
  local phome="${SANDBOX}/pathhome"; mkdir -p "${phome}"
  printf '# existing rc\n' > "${phome}/.zshrc"
  (cd "${ROOT}" && HOME="${phome}" AGENTKIT_ENV="${phome}/env" AGENTKIT_HOME="${phome}/kit" \
    bash install.sh >/dev/null 2>&1) || true
  (cd "${ROOT}" && HOME="${phome}" AGENTKIT_ENV="${phome}/env" AGENTKIT_HOME="${phome}/kit" \
    bash install.sh >/dev/null 2>&1) || true
  local hits
  hits="$(grep -c 'coding-agents-kit/bin' "${phome}/.zshrc" || true)"
  if [[ "${hits}" -eq 1 ]]; then pass "PATH wiring is idempotent (exactly one block)"; else fail "PATH block written ${hits} times"; fi
  if grep -q '^# existing rc$' "${phome}/.zshrc"; then pass "PATH wiring preserves the existing rc"; else fail "PATH wiring damaged the rc"; fi
}

run_status() {
  echo "## status / doctor (sandbox HOME, fake env with a dummy key)"
  local envf="${SANDBOX}/env"
  printf 'XAI_API_KEY=dummy-secret-value-do-not-print\n' > "${envf}"
  local out
  out="$(cd "${ROOT}" && HOME="${SANDBOX}" AGENTKIT_ENV="${envf}" AGENTKIT_HOME="${SANDBOX}/kit" \
        bash -c 'source lib/common.sh; source lib/onboard.sh; agentkit_status; agentkit_plan' 2>&1)"
  if grep -q 'env XAI_API_KEY: set' <<<"${out}"; then pass "status reports a set key by name"; else fail "status did not report XAI_API_KEY as set"; fi
  if grep -q 'dummy-secret-value' <<<"${out}"; then fail "status leaked a secret value"; else pass "status never prints secret values"; fi
  if grep -qE '^cli claude: (installed|missing)' <<<"${out}"; then pass "status lists CLIs"; else fail "status CLI section missing"; fi
  if grep -q '## Onboard plan' <<<"${out}"; then pass "plan section present"; else fail "plan section missing"; fi
  if grep -qE '^os: (macos|linux|windows|unknown)' <<<"${out}"; then pass "status reports the host OS"; else fail "status did not report the OS"; fi

  out="$(cd "${ROOT}" && HOME="${SANDBOX}" bash install.sh --help 2>&1)"
  if grep -q -- '--onboard' <<<"${out}"; then pass "install.sh --help"; else fail "install.sh --help"; fi

  # A fresh machine must not be told it is set up.
  local fresh="${SANDBOX}/freshhome"; mkdir -p "${fresh}"
  out="$( cd "${ROOT}" && HOME="${fresh}" AGENTKIT_ENV="${fresh}/env" bash bin/agentkit onboard clis 2>&1 || true )"
  if grep -q 'nothing — this machine is set up' <<<"${out}"; then
    fail "a machine with no env file and no PATH was called set up"
  else
    pass "a machine with no env file and no PATH is not called set up"
  fi

  out="$(cd "${ROOT}" && HOME="${SANDBOX}" bash bin/agentkit --help 2>&1 || true)"
  if grep -q 'env-path' <<<"${out}"; then pass "agentkit --help prints usage"; else fail "agentkit --help printed nothing"; fi
  if ( cd "${ROOT}" && HOME="${SANDBOX}" bash bin/agentkit not-a-verb ) >/dev/null 2>&1; then
    fail "an unknown command exited 0"
  else
    pass "an unknown command exits non-zero"
  fi

  out="$(cd "${ROOT}" && HOME="${SANDBOX}" REMOTE_CONTAINERS=true bash bin/agentkit onboard 2>&1 || true)"
  if grep -q 'runs on the host machine itself' <<<"${out}"; then
    pass "agentkit onboard refuses inside a container"
  else
    fail "agentkit onboard did not refuse inside a container"
  fi
  out="$(cd "${ROOT}" && HOME="${SANDBOX}" REMOTE_CONTAINERS=true bash bin/agentkit status 2>&1 || true)"
  if grep -q "inside a container" <<<"${out}" && grep -q '## Prerequisites' <<<"${out}"; then
    pass "agentkit status warns in a container and still reports"
  else
    fail "agentkit status container warning missing"
  fi

  # Every provider wrapper must fail by NAME when its variable is missing.
  local wrapper
  for wrapper in codex-xai opencode-glm pi-azure; do
    out="$(cd "${ROOT}" && HOME="${SANDBOX}" AGENTKIT_ENV="${SANDBOX}/empty-env" \
          env -u XAI_API_KEY -u ZAI_CODING_API_KEY -u AZURE_OPENAI_API_KEY \
          bash "bin/${wrapper}" 2>&1 || true)"
    if grep -qE 'is not on PATH|is not set' <<<"${out}"; then
      pass "${wrapper} fails fast naming the missing CLI or variable"
    else
      fail "${wrapper} did not fail with a named reason (got: ${out})"
    fi
  done
}

run_win() {
  echo "## windows layer (static checks — PowerShell is not run here)"
  local w name missing=0
  # Every Unix wrapper has a Windows shim and vice versa.
  for w in "${ROOT}"/bin/*; do
    name="$(basename "${w}")"
    [[ "${name}" == *.md ]] && continue
    [[ -f "${ROOT}/win/bin/${name}.cmd" ]] || { missing=1; echo "     missing win/bin/${name}.cmd"; }
  done
  if [[ "${missing}" -eq 0 ]]; then pass "every bin/ wrapper has a win/bin/*.cmd shim"; else fail "a wrapper has no Windows shim"; fi

  missing=0
  for w in "${ROOT}"/win/bin/*.cmd; do
    name="$(basename "${w}" .cmd)"
    [[ -f "${ROOT}/bin/${name}" ]] || { missing=1; echo "     extra win/bin/${name}.cmd"; }
  done
  if [[ "${missing}" -eq 0 ]]; then pass "every win/bin/*.cmd shim has a bin/ wrapper"; else fail "a Windows shim has no Unix wrapper"; fi

  # The dispatcher must handle every CLI wrapper name it is called with.
  missing=0
  for w in "${ROOT}"/win/bin/*.cmd; do
    name="$(basename "${w}" .cmd)"
    case "${name}" in agentkit|agentbox) continue ;; esac
    grep -q "'${name}'" "${ROOT}/win/lib/Invoke-Wrapper.ps1" || { missing=1; echo "     ${name} not handled in Invoke-Wrapper.ps1"; }
  done
  if [[ "${missing}" -eq 0 ]]; then pass "Invoke-Wrapper.ps1 handles every wrapper name"; else fail "a wrapper name is unhandled in the dispatcher"; fi

  # Encoding is checked in Python: BSD and GNU grep disagree about bracket
  # expressions, and a grep that errors out looks exactly like a passing check.
  if python3 - "${ROOT}" <<'PYEOF'
import glob, os, sys
root = sys.argv[1]
bad = []
for path in sorted(glob.glob(os.path.join(root, "win", "bin", "*.cmd"))):
    data = open(path, "rb").read()
    name = os.path.basename(path)
    if b"\r\n" not in data:
        bad.append("%s: not CRLF" % name)
    if any(b > 126 or (b < 32 and b not in (9, 10, 13)) for b in data):
        bad.append("%s: non-ASCII bytes" % name)
for line in bad:
    sys.stderr.write("     %s\n" % line)
raise SystemExit(1 if bad else 0)
PYEOF
  then pass "win/bin/*.cmd are CRLF and ASCII-only"; else fail "a .cmd shim has the wrong encoding"; fi

  # Shell scripts must stay LF, or bash inside WSL or Git Bash breaks on \r.
  if python3 - "${ROOT}" <<'PYEOF'
import glob, os, sys
root = sys.argv[1]
targets = sorted(glob.glob(os.path.join(root, "bin", "*")) +
                 glob.glob(os.path.join(root, "lib", "*.sh")) +
                 [os.path.join(root, "install.sh"), os.path.join(root, "tests", "run.sh")])
bad = [os.path.basename(p) for p in targets
       if not p.endswith(".md") and b"\r" in open(p, "rb").read()]
for name in bad:
    sys.stderr.write("     %s contains CR\n" % name)
raise SystemExit(1 if bad else 0)
PYEOF
  then pass "shell scripts and lib are LF-only"; else fail "a shell script has CRLF endings"; fi

  check "install.ps1 exists" test -f "${ROOT}/install.ps1"
  check "the Windows modules exist" test -f "${ROOT}/win/lib/AgentKit.psm1" -a -f "${ROOT}/win/lib/Onboard.psm1"
  if command -v pwsh >/dev/null 2>&1; then
    check "pwsh parses the Windows layer" pwsh -NoProfile -Command "
      \$ErrorActionPreference='Stop'
      Get-ChildItem -Path '${ROOT}/win' -Recurse -Include *.ps1,*.psm1 | ForEach-Object {
        \$errs = \$null
        [void][System.Management.Automation.Language.Parser]::ParseFile(\$_.FullName, [ref]\$null, [ref]\$errs)
        if (\$errs) { throw \$_.FullName }
      }
      \$errs = \$null
      [void][System.Management.Automation.Language.Parser]::ParseFile('${ROOT}/install.ps1', [ref]\$null, [ref]\$errs)
      if (\$errs) { throw 'install.ps1' }"
  else
    echo "  skip pwsh parse (not installed — the Windows layer is marked unverified in docs/WINDOWS.md)"
  fi
}

case "${SCOPE}" in
  all) run_lint; run_writers; run_resolver; run_herdr; run_machines; run_onboard; run_status; run_win ;;
  lint) run_lint ;;
  writers) run_writers ;;
  resolver) run_resolver ;;
  herdr) run_herdr ;;
  machines) run_machines ;;
  onboard) run_onboard ;;
  status) run_status ;;
  win) run_win ;;
  *) echo "usage: tests/run.sh [all|lint|writers|resolver|herdr|machines|onboard|status|win]" >&2; exit 2 ;;
esac

echo ""
echo "passed: ${PASSES}  failed: ${FAILS}"
[[ "${FAILS}" -eq 0 ]]
