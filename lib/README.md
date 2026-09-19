# `lib/` — shared helpers, config writers, and `agentbox`

| File | Role |
| --- | --- |
| `common.sh` | Sourced by every wrapper. Loads the env file (`AGENTKIT_ENV`, default `~/.config/coding-agents-kit/env`) with `set -a`; defines `agentkit_require_*` guards (fail fast, print names never values), `agentkit_os`, the Azure base-URL helper, and the **Cursor-vs-Grok resolver** (`agentkit_cursor_bin`, `agentkit_is_cursor_binary`). |
| `host.sh` | Host-vs-container detection (`agentkit_in_container`, `agentkit_require_host`). Sourced by `common.sh`, and **directly** by `bin/agentbox` — that command must not load the env file, because a value written there could silently change which machines file it acts on. Deliberately side-effect free. |
| `herdr.sh` | Herdr machine lookup and state changes for shell callers: `herdr_kit_available`, `herdr_kit_machine_for` / `_machine_id` (matches a machine by its `target` against an SSH alias, so no id is ever configured), `herdr_kit_set_state`, `herdr_kit_ssh_alias_defined` (via `ssh -G`). Degrades four ways — herdr absent, machine absent, call failed, lib absent — each warning once per process and **never** changing the caller's exit code. |
| `onboard.sh` | Sourced by `install.sh` and `bin/agentkit`. Detection (`agentkit_status`, `agentkit_plan`), PATH wiring, env-file creation (never overwrites), wrapper copy, the missing-CLI installer, and the onboarding areas (`clis`, `machines`, `herdr`). |
| `agentbox.py` | The machines command: parses your `machines.toml`, drives each machine's own compose file, reaches it over SSH, renders the kit-owned SSH include, and keeps its Herdr machine in step. Stdlib Python, identical on all three OSes. |
| `write_codex_profile.py` | Writes the kit-owned Codex profile overlay `<CODEX_HOME>/<provider>.config.toml` with `env_key`. Rewritten on every launch. |
| `write_opencode_provider.py` | Merges one `provider.<id>` block (`{env:KEY}`) into `opencode.json`. Never sets the global `model`; refuses invalid JSON; atomic write; one-time `.agentkit.bak`. |
| `write_pi_provider.py` | Upserts one provider into `models.json` (`"apiKey": "$KEY"`). Same merge / refuse / atomic / backup rules. |

## Rules for this folder

- A writer may only add or replace **the block it owns**. Everything else in a
  user-owned file — other providers, global defaults, themes, plugins — is
  preserved.
- A writer never writes a secret value, only an env reference the CLI resolves at
  runtime.
- On unparsable input: exit 1 with a prefixed message on stderr, and leave the
  file exactly as it was. Never start from `{}`.
- Python here is **stdlib only** and must run on whatever Python 3 a machine
  already has — that is why `agentbox.py` parses its own documented TOML subset
  instead of requiring `tomllib` (3.11+).
- Every writer has a test in `tests/run.sh writers`; `herdr.sh` and `host.sh` are
  covered by `herdr`, `machines` and `status`, all against stubs and a sandbox
  `HOME`, so the suite never needs a real Herdr, a real container or a network.
