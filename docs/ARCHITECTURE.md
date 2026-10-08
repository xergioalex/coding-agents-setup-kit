# Architecture

## Components

```
coding-agents-setup-kit/          (copied to ~/.local/share/coding-agents-kit on install)
├── install.sh                    idempotent installer / onboard (macOS, Linux, WSL, Git Bash)
├── install.ps1                   the same on Windows PowerShell
├── bin/                          23 executables
│   ├── claudex, claude-glm, claudex-glm
│   ├── codexx, codex-azure, codex-xai, codex-glm
│   ├── cursorx
│   ├── opencodex, opencode-azure, opencode-xai, opencode-glm
│   ├── pix, pi-azure, pi-xai, pi-glm
│   ├── clinex, cline-azure, clinex-azure, cline-xai
│   ├── grokx
│   ├── agentkit                  status | doctor | onboard | path | env-path | machines-path
│   └── agentbox                  machines: up/stop/down/ssh/herdr/ssh-config/doctor
├── win/
│   ├── bin/*.cmd                 one shim per wrapper (PATH entry point on Windows)
│   └── lib/                      AgentKit.psm1, Onboard.psm1, Invoke-Wrapper.ps1, entry points
├── lib/
│   ├── common.sh                 env loader, require_* guards, OS probe, Azure URL, Cursor-vs-Grok resolver
│   ├── host.sh                   host-vs-container check; side-effect free, so agentbox can source it alone
│   ├── herdr.sh                  machine lookup by SSH target, enable/disable; degrades without ever failing a caller
│   ├── onboard.sh                detection, plan, PATH wiring, env file, wrapper copy, CLI gap-fill, areas
│   ├── agentbox.py               the machines command (stdlib Python, shared by all three OSes)
│   ├── write_codex_profile.py    <CODEX_HOME>/<provider>.config.toml   (env_key)
│   ├── write_opencode_provider.py  opencode.json                      (provider merge, {env:KEY})
│   └── write_pi_provider.py      ~/.pi/agent/models.json              (provider upsert, "$KEY")
├── env.example                   variable names only
├── machines.example.toml         optional machine list (you write the real one)
└── tests/run.sh                  the validation gate (sandbox HOME; no installs, no network)
```

## Runtime flow of a wrapper

```
user runs `codex-glm -c`
  └─ bin/codex-glm
       ├─ source lib/common.sh
       │    └─ set -a; source ~/.config/coding-agents-kit/env; set +a   (this process only)
       ├─ agentkit_require_cmd codex        → "codex is not on PATH" and exit 1
       ├─ agentkit_require_zai              → "ZAI_CODING_API_KEY is not set" and exit 1
       ├─ python3 lib/write_codex_profile.py ~/.codex/glm.config.toml ZAI … ZAI_CODING_API_KEY glm-5.3-flash
       └─ exec codex -p glm resume --last --dangerously-bypass-approvals-and-sandbox
```

Three layers, strictly ordered: **wrapper** (argument mapping) → **lib** (env,
guards, config writers) → **official CLI** (`exec`, so the wrapper process is
replaced and signals reach the CLI directly).

On Windows the same three layers exist, with one difference that matters:
PowerShell has no `exec`, so the shim stays as a parent process. See
[`WINDOWS.md`](WINDOWS.md).

## Where state lives

| Purpose | macOS / Linux | Windows |
| --- | --- | --- |
| kit executables | `~/.local/share/coding-agents-kit/bin` | `%LOCALAPPDATA%\coding-agents-kit\bin` |
| kit libraries | `~/.local/share/coding-agents-kit/lib` | `%LOCALAPPDATA%\coding-agents-kit\lib` |
| **your** env file | `~/.config/coding-agents-kit/env` (chmod 600) | `%APPDATA%\coding-agents-kit\env` (ACL: you only) |
| **your** machines file | `~/.config/coding-agents-kit/machines.toml` | `%APPDATA%\coding-agents-kit\machines.toml` |
| PATH | one guarded block in your shell rc | the **user** `Path` variable (machine `Path` untouched) |
| Codex provider overlay | `~/.codex/<provider>.config.toml` (kit-owned) | `%USERPROFILE%\.codex\…` |
| **your** OpenCode config | `~/.config/opencode/opencode.json` — only `provider.<id>` merged | `%APPDATA%\opencode\opencode.json` |
| **your** Pi models | `~/.pi/agent/models.json` — only `providers.<id>` upserted | `%USERPROFILE%\.pi\agent\models.json` |
| the CLIs' own installs | wherever their installers put them | idem — never moved by this kit |

Rows marked **your** are user-owned: the kit merges the one block it owns and
preserves everything else. Rows marked kit-owned are regenerated freely.

## Key decisions

- **Executables, not shell functions.** A function only exists in an interactive
  shell that sourced it. The kit's commands have to work from zsh, from bash,
  from `herdr agent start`, from a script and from a non-interactive agent
  session — so `bin/*`.
- **The env file lives in your home, not in a repo.** Secrets survive repo
  switches and are never one `git add` away from being published. Wrappers
  export them for their own process only.
- **Provider config is regenerated per launch** (Codex overlay) or merged per
  launch (OpenCode, Pi). It costs one `python3` run and it means editing the env
  file is enough to change model or endpoint — there is no second source of truth.
- **Cursor is resolved, never assumed.** `command -v agent` can be the Grok CLI.
  `agentkit_cursor_bin` prefers `cursor-agent`, rejects Grok by path and by
  version banner, and falls back to Cursor's own versioned install directory.
- **Writers fail closed.** Unparsable user config → exit 1 and leave it alone.
  Never start from `{}`.
- **One Python for everything cross-platform.** `agentbox` and the three config
  writers are stdlib Python, identical on all three OSes, so the Windows layer
  only has to solve *launching*, not logic.
- **npm before pnpm.** `pnpm add -g` fails without a global bin dir, and creating
  one (`pnpm setup`) edits the user's rc files. The kit never does that.
- **No machine list.** `agentbox` reads a file you write. A tool that ships
  someone else's hosts is a tool nobody else can use.

## Relationship to Herdr

The kit does not wrap `herdr`; it installs the official client when missing and
documents it ([`herdr/`](herdr/README.md)). Inside a Herdr pane on your machine
the kit's wrappers apply exactly as in any other terminal. Inside a Herdr remote
session, whatever that machine has applies — which is why
[`herdr/05-container-setup.md`](herdr/05-container-setup.md) shows how to put
this kit (or just the CLIs) inside a container image.

`agentbox` is the only part that talks to Herdr, and only to enable, disable,
create or list a saved machine — never to change one that already exists.
