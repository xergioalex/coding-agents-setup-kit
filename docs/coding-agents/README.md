# Coding agents — per-CLI guides

One page per CLI this kit wraps: how it is installed on each OS, how it
authenticates, the flags the wrappers rely on (with the version they were
verified against), how sessions work, and the provider variants.

| Page | CLI | Wrappers |
| --- | --- | --- |
| [`claude-code.md`](claude-code.md) | Claude Code (`claude`) | `claudex`, `claude-glm` (`claudex-glm`) |
| [`codex.md`](codex.md) | OpenAI Codex CLI (`codex`) | `codexx`, `codex-azure`, `codex-xai`, `codex-glm` |
| [`cursor-agent.md`](cursor-agent.md) | Cursor Agent CLI (`cursor-agent` / `agent`) | `cursorx` |
| [`opencode.md`](opencode.md) | OpenCode (`opencode`) | `opencodex`, `opencode-azure`, `opencode-xai`, `opencode-glm` |
| [`pi.md`](pi.md) | Pi coding agent (`pi`) | `pix`, `pi-azure`, `pi-xai`, `pi-glm` |
| [`cline.md`](cline.md) | Cline CLI (`cline`) | `clinex`, `cline-azure` (`clinex-azure`), `cline-xai` |
| [`grok.md`](grok.md) | xAI Grok CLI (`grok`) | `grokx` |
| [`providers.md`](providers.md) | Z.AI GLM, Azure OpenAI / Foundry, xAI — variables, endpoints, which wrapper uses what | — |
| [`wrappers-reference.md`](wrappers-reference.md) | One table: every wrapper, what it runs, what it requires, what it writes | all |

Choosing *which model and effort* to run inside these CLIs:
[`../model-strategy/README.md`](../model-strategy/README.md).

## Verification legend

- **verified** — read from the named installed version's `--help` or from the
  vendor's official reference, on the date given.
- **unverified on host** — carried over from another platform or machine. Run
  `<cli> --help` before relying on it, then send a pull request updating the page.

The verifications recorded here were done on **macOS**. Where a CLI behaves
differently on Linux or Windows, the page says so; where nobody has checked, it
says that too.

## Adding a CLI to the kit

1. Verify its install command per OS from the vendor's own page.
2. Verify its full-permission flag and its session flags from `--help`.
3. Add the wrapper in `bin/` **and** the shim + dispatcher branch in `win/`.
4. Add it to `AGENTKIT_CLIS` / `AGENTKIT_WRAPPERS` in `lib/onboard.sh` and to
   `$script:Clis` / `$script:Wrappers` in `win/lib/Onboard.psm1`.
5. Add a page here, `bin/README.md` and `wrappers-reference.md`.
6. Add a check to `tests/run.sh`, and run the gate.
