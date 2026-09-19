# Wrapper reference

Every command the kit installs: what it runs, what it needs, what it writes.
`bin/README.md` carries the same table next to the code.

| Wrapper | Executes | Requires | Writes |
| --- | --- | --- | --- |
| `claudex [-c\|-r [id]] …` | `claude --dangerously-skip-permissions` (+ `--continue` / `--resume [id]`) | `claude` | — |
| `claude-glm …` (`claudex-glm`) | the same, with `ANTHROPIC_*` set for the process | `claude`, `ZAI_CODING_API_KEY` | — |
| `codexx [-c\|-l\|-r [id]] …` | `codex --dangerously-bypass-approvals-and-sandbox` (+ `resume --last` / `resume <id>` / `resume --all`) | `codex` | — |
| `codex-azure` / `codex-xai` / `codex-glm` | `codex -p <azure\|xai\|glm> …` | `codex` + that provider's variables | `<CODEX_HOME>/<provider>.config.toml` |
| `cursorx [-c\|-l\|-r [id]] …` | `<resolved cursor-agent> --force` (+ `--continue` / `ls` / `--resume[=id]`); `CURSORX_SANDBOX` adds `--sandbox` | the Cursor CLI (resolved, never Grok) | — |
| `opencodex …` | `opencode --auto` | `opencode` | — |
| `opencode-azure` / `-xai` / `-glm` | `opencode --auto -m <provider>/<model>` | `opencode` + provider variables | `provider.<id>` inside `opencode.json` |
| `pix …` | `pi --approve` | `pi` | — |
| `pi-azure` / `-xai` / `-glm` | `pi --approve --provider <id> --model … --models …` | `pi` + provider variables | `providers.<id>` inside `models.json` |
| `clinex …` | `cline --yolo` | `cline` | — |
| `cline-azure` (`clinex-azure`) / `cline-xai` | `cline auth -p openai …` then `cline --yolo -P openai -m … -k …` | `cline` + provider variables | Cline's auth store (**key on argv**) |
| `grokx [-c\|-r [id]] …` | `grok` (+ `--continue` / `--resume`) | `grok`; key optional | — |
| `agentkit status\|doctor\|onboard\|path\|env-path\|machines-path` | detection and gap reporting | — | via `install.sh` only: the wrappers dir, the PATH block, the env file when missing |
| `agentbox ls\|status\|up\|stop\|down\|restart\|ssh\|herdr\|ssh-config\|doctor` | your machines' own compose files, `ssh`, and `herdr machine …` | a machines file; `docker` for lifecycle; `herdr` only for the machine half | nothing of its own, except `~/.ssh/config.d/coding-agents-kit` on `ssh-config --write` |

## Session-flag contract

| Flag | Meaning |
| --- | --- |
| `-c`, `--continue` | continue the most recent session |
| `-r`, `--resume [id]` | resume by id, or the CLI's picker |
| `-l` | Codex: `resume --last`; Cursor: `ls` |
| everything else | forwarded verbatim, after the kit's own flags |

## Environment knobs

`AGENTKIT_ENV` (env file path) · `AGENTKIT_HOME` (install dir) ·
`AGENTKIT_MACHINES` (machines file) · `AGENTKIT_SSH_INCLUDE` (generated ssh
include) · `AGENTBOX_NO_HERDR` · `CODEX_HOME` · `OPENCODE_CONFIG` ·
`PI_MODELS_FILE` · `CURSORX_SANDBOX`.

## Exit codes

`1` with an `agentkit: …` / `agentbox: …` message when a CLI or a required
variable is missing, or when a writer refuses an unparsable config. Otherwise
the wrapped CLI's own exit code — the Unix wrappers `exec` it, and the Windows
shims forward `$LASTEXITCODE`.
