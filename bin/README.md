# `bin/` — the wrappers

Every file here is an executable installed to
`~/.local/share/coding-agents-kit/bin/` (on PATH). Each one:

1. sources `../lib/common.sh` — which loads your env file into this process and
   defines the guards, the OS probe and the Cursor-vs-Grok resolver;
2. checks the official CLI is present (`agentkit_require_cmd`) and, for provider
   variants, that the provider's variables are set — failing fast with the
   **name**, never the value;
3. for provider variants, refreshes that provider's config through a `lib/`
   writer (Codex overlay, OpenCode merge, Pi upsert);
4. `exec`s the official CLI with the full-permission flag and the mapped session
   flags.

The Windows equivalents are `../win/bin/<name>.cmd` plus one dispatcher,
`../win/lib/Invoke-Wrapper.ps1`. The gate asserts that every name exists on both
sides.

| Wrapper | CLI | Full-permission flag | `-c` | `-r [id]` | Other | Provider |
| --- | --- | --- | --- | --- | --- | --- |
| `claudex` | `claude` | `--dangerously-skip-permissions` | `--continue` | `--resume [id]` | | your Anthropic login |
| `claude-glm` (`claudex-glm`) | `claude` | same | pass-through | pass-through | | Z.AI, via process-scoped `ANTHROPIC_*` |
| `codexx` | `codex` | `--dangerously-bypass-approvals-and-sandbox` | `resume --last` (`-l` too) | `resume <id>` / `resume --all` | | your OpenAI login |
| `codex-azure` / `codex-xai` / `codex-glm` | `codex -p <profile>` | same | same | same | writes `<CODEX_HOME>/<provider>.config.toml` | Azure / xAI / Z.AI |
| `cursorx` | Cursor `cursor-agent` | `--force` | `--continue` | `--resume=<id>` / `--resume` | `-l` → `ls`; `CURSORX_SANDBOX` → `--sandbox` | your Cursor login |
| `opencodex` | `opencode` | `--auto` | pass-through | pass-through | | your OpenCode providers |
| `opencode-azure` / `-xai` / `-glm` | `opencode --auto -m <provider>/<model>` | `--auto` | pass-through | pass-through | merges `provider.<id>` into `opencode.json` | Azure / xAI / Z.AI |
| `pix` | `pi` | `--approve` | pass-through | pass-through | `--thinking <level>` for effort | your Pi providers |
| `pi-azure` / `-xai` / `-glm` | `pi --approve --provider <id>` | `--approve` | pass-through | pass-through | upserts `models.json` | Azure / xAI / Z.AI |
| `clinex` | `cline` | `--yolo` | | | | your Cline provider |
| `cline-azure` (`clinex-azure`) / `cline-xai` | `cline auth` + `cline --yolo -P openai` | `--yolo` | | | **key on argv** — see SECURITY | Azure / xAI |
| `grokx` | `grok` | (Grok has none) | `--continue` | `--resume` | key optional after `grok login` | xAI |
| `agentkit` | — | — | — | — | `status` / `doctor` / `onboard` / `path` / `env-path` / `machines-path` | — |
| `agentbox` | — | — | — | — | `ls` / `status` / `up` / `stop` / `down` / `restart` / `ssh` / `herdr` / `ssh-config` / `doctor` | — |

Tests: `tests/run.sh resolver`, `tests/run.sh status`, `tests/run.sh machines`,
`tests/run.sh win`. Per-CLI notes: [`../docs/coding-agents/`](../docs/coding-agents/README.md).

## Rules for this folder

- No markdown here except this file: the installer strips `*.md` from the PATH
  directory, and `bin/*` globs would otherwise try to execute it.
- `exec` is the last statement of a wrapper — no cleanup code after it.
- A new wrapper is not finished until it exists in `win/`, is registered in
  `lib/onboard.sh` and `win/lib/Onboard.psm1`, appears in this table and in
  `docs/coding-agents/wrappers-reference.md`, and has a check in the gate.

## `agentbox` is different

Unlike the CLI wrappers, `agentbox` sources `../lib/host.sh` rather than
`../lib/common.sh`. `common.sh` exports your env file, and a value written there
must not silently change which machines file the command acts on. `host.sh` is
side-effect free and carries only the host-vs-container check.

Full guide: [`../docs/machines.md`](../docs/machines.md).
