# Install

Works on **macOS**, **Linux**, **WSL2** and **Windows**. Safe on a machine that
already has some of these tools: onboarding detects and keeps them, installs only
what is missing, and never overwrites your env file or your CLI configs.

## macOS, Linux, WSL

```bash
git clone https://github.com/xergioalex/coding-agents-setup-kit.git
cd coding-agents-setup-kit
chmod +x install.sh bin/* lib/*.sh
./install.sh --onboard          # Before → plan → fill gaps → After
```

Open a new terminal, then:

```bash
agentkit status
claudex
```

| Flag | What it does |
| --- | --- |
| (none) | copy the wrappers, wire PATH, create the env file if missing |
| `--onboard` | print what is installed and the plan, then fill the gaps (implies `--clis`) |
| `--clis` | install missing official CLIs only |
| `--no-path` | do not touch your shell rc |

## Windows

```powershell
git clone https://github.com/xergioalex/coding-agents-setup-kit.git
cd coding-agents-setup-kit
.\install.ps1 -Onboard
```

Open a **new** terminal (the installer edits your user `Path`), then
`agentkit status`.

Read [`docs/WINDOWS.md`](docs/WINDOWS.md) before you start: it explains the
native-versus-WSL choice, Execution Policy, the Mark-of-the-Web warning, and
which parts of the Windows layer are still `unverified on host`.

## What gets installed where

| Purpose | macOS / Linux | Windows |
| --- | --- | --- |
| wrappers | `~/.local/share/coding-agents-kit/bin` | `%LOCALAPPDATA%\coding-agents-kit\bin` |
| your env file | `~/.config/coding-agents-kit/env` (chmod 600) | `%APPDATA%\coding-agents-kit\env` (ACL: you only) |
| PATH | one guarded block appended to your shell rc | your **user** `Path` (machine `Path` untouched) |

Nothing else is modified. The CLIs stay wherever their own installers put them.

## The CLIs

`--onboard` installs the ones it has a verified path for on your OS, using the
vendors' own installers, and reports the rest with a link instead of guessing:

| CLI | macOS / Linux | Windows |
| --- | --- | --- |
| Claude Code | `curl -fsSL https://claude.ai/install.sh \| bash` | vendor PowerShell installer (unverified here) |
| OpenAI Codex | `npm install -g @openai/codex` | same |
| Cline | `npm install -g cline` | same |
| Pi | `npm install -g --ignore-scripts @earendil-works/pi-coding-agent` | same |
| Cursor Agent | `curl -fsSL https://cursor.com/install \| bash` | see <https://cursor.com/docs/cli> |
| OpenCode | `curl -fsSL https://opencode.ai/install \| bash` | see <https://opencode.ai/docs> |
| xAI Grok | `curl -fsSL https://x.ai/cli/install.sh \| bash` | see <https://x.ai/cli> |
| Herdr | `curl -fsSL https://herdr.dev/install.sh \| sh` | see <https://herdr.dev/docs/install/> |

Node and Python are prerequisites, not things the kit installs for you: several
CLIs are npm packages, and the provider config writers are stdlib Python 3. The
doctor tells you if either is missing, and how to get it on your OS.

If you would rather not run a vendor's `curl | bash`, install those CLIs by hand
and run `agentkit status` — the kit detects and keeps whatever is there.

## Your keys

```bash
agentkit env-path        # prints the file
```

Edit that file yourself. It starts as **names only**; uncomment and fill what you
use. Nothing else in the kit ever reads it, writes it, or prints a value from it.

| You want | Set |
| --- | --- |
| `claude-glm`, `codex-glm`, `opencode-glm`, `pi-glm` | `ZAI_CODING_API_KEY` |
| `codex-xai`, `opencode-xai`, `pi-xai`, `cline-xai` | `XAI_API_KEY` |
| `grokx` | nothing — run `grok login` (or set `XAI_API_KEY`) |
| any `*-azure` | `AZURE_OPENAI_API_KEY`, `AZURE_OPENAI_RESOURCE` (or `_BASE_URL`), `AZURE_OPENAI_MODEL_DAILY` |
| `claudex`, `codexx`, `cursorx`, `opencodex`, `pix`, `clinex` | nothing — they use the login you already have |

Details, endpoints and model variables: [`docs/coding-agents/providers.md`](docs/coding-agents/providers.md).

## Verify

```bash
agentkit status          # CLIs, wrappers, PATH, which keys are set (by name)
agentkit onboard         # the same, plus a checklist of what is left for you
```

## Optional: your machines

```bash
cp machines.example.toml "$(dirname "$(agentkit env-path)")/machines.toml"
$EDITOR "$(dirname "$(agentkit env-path)")/machines.toml"
agentbox ls
```

See [`docs/machines.md`](docs/machines.md).

## Updating

```bash
git pull && ./install.sh          # wrappers are refreshed; your env file is untouched
```

## Uninstalling

```bash
rm -rf ~/.local/share/coding-agents-kit
# remove the "# coding-agents-setup-kit" block from your shell rc
# your env file in ~/.config/coding-agents-kit is left alone on purpose
```

Windows: delete `%LOCALAPPDATA%\coding-agents-kit` and remove that bin path from
your user `Path`.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `claudex: command not found` | new terminal, or `export PATH="$HOME/.local/share/coding-agents-kit/bin:$PATH"` |
| `agentkit: <cli> is not on PATH` | that CLI is not installed — `./install.sh --clis`, or install it by hand |
| `agentkit: XAI_API_KEY is not set` | add it to your env file; `agentkit env-path` says where |
| `cursorx` says Cursor is not found, but `agent --version` works | that `agent` is the Grok CLI. Install Cursor's own CLI |
| a writer refuses your `opencode.json` | it is not valid JSON. Fix it (or point `OPENCODE_CONFIG` elsewhere) — the kit will not overwrite what it cannot parse |
| Cline exits immediately with no output | a blocked or unsigned binary — see [`docs/coding-agents/cline.md`](docs/coding-agents/cline.md) |
