# coding-agents-setup-kit

Install every terminal coding agent on **macOS, Linux or Windows**, give them one
uniform command surface with full permissions, add provider variants (Z.AI GLM,
xAI, Azure OpenAI) that **never write an API key to disk** — and learn to run
them all inside [Herdr](https://herdr.dev), locally or over SSH.

```bash
git clone https://github.com/xergioalex/coding-agents-setup-kit.git
cd coding-agents-setup-kit
./install.sh --onboard        # macOS / Linux / WSL   (Windows: .\install.ps1 -Onboard)

# new terminal
agentkit status
claudex
```

Safe on a machine that already has some of these tools: onboarding **detects and
keeps** what is there, installs only what is missing, and never overwrites your
env file or your OpenCode / Pi / Codex configs.

## The command surface

One short command per agent, with full permissions and the same session flags
everywhere (`-c` continue, `-r [id]` resume, `-l` list, everything else passed
through):

| CLI | your own login | Z.AI GLM | Azure OpenAI | xAI |
| --- | --- | --- | --- | --- |
| Claude Code | `claudex` | `claude-glm` | — | — |
| OpenAI Codex | `codexx` | `codex-glm` | `codex-azure` | `codex-xai` |
| Cursor Agent | `cursorx` | — | — | — |
| OpenCode | `opencodex` | `opencode-glm` | `opencode-azure` | `opencode-xai` |
| Pi | `pix` | `pi-glm` | `pi-azure` | `pi-xai` |
| Cline | `clinex` | — | `cline-azure` | `cline-xai` |
| xAI Grok | `grokx` | — | — | native |

Plus `agentkit` (the doctor: what is installed, what is missing, which keys are
set — **by name, never by value**) and `agentbox` (start the containers or boxes
you run agents on, and keep their Herdr machines in step).

## Why it exists

Every one of these CLIs has its own installer, its own "skip the prompts" flag,
its own config file and its own way of pointing at a different provider. Doing
that by hand on each machine takes an afternoon and produces a different setup
every time — usually with API keys pasted into config files. This kit makes it
one command, and writes down what it learned so you can audit every choice.

## Layout

| Path | Role |
| --- | --- |
| `bin/` | The wrappers (bash) and the doctor. [`bin/README.md`](bin/README.md) |
| `win/` | The same surface on Windows: `.cmd` shims + PowerShell. [`docs/WINDOWS.md`](docs/WINDOWS.md) |
| `lib/` | Env loader, Cursor-vs-Grok resolver, merge-safe config writers, `agentbox`. [`lib/README.md`](lib/README.md) |
| `install.sh` · `install.ps1` | Idempotent installers |
| `env.example` · `machines.example.toml` | Variable names only · optional machine list |
| `tests/run.sh` | The validation gate (sandbox HOME, no installs, no network) |
| `docs/` | [Index](docs/README.md) · [per-CLI](docs/coding-agents/README.md) · [Herdr](docs/herdr/README.md) · [model strategy](docs/model-strategy/README.md) |
| `AGENTS.md` | Entry point for AI agents working **on** this repo |

## What it will not do

- Write a secret into a config file. Codex gets `env_key`, OpenCode `{env:KEY}`,
  Pi `"$KEY"`; the value stays in your env file. Cline is the one documented
  exception (it takes the key on argv) — see [SECURITY](docs/SECURITY.md).
- Overwrite a config it did not write, or one it cannot parse.
- Rewrite OpenCode's global `model`, or edit your shell rc beyond one guarded block.
- Uninstall, move or re-link a CLI you already had.
- Trust a bare `agent` command as Cursor — the Grok CLI installs one too.
- Invent an install command. Where this kit has no verified path for your OS, it
  says so and links the vendor.

## License

MIT — see [`LICENSE`](LICENSE).
