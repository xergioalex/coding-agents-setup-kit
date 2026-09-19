# OpenAI Codex CLI (`codex`)

| | |
| --- | --- |
| Install (any OS) | `npm install -g @openai/codex` |
| Auth | run `codex` → OpenAI login, stored in `~/.codex/auth.json`. Provider variants use their own key through `env_key` |
| Config | `~/.codex/config.toml` is **yours** and untouched; the kit writes profile overlays `~/.codex/<name>.config.toml` |
| Verified against | codex-cli **0.144.4** (`codex --help`, `codex resume --help`, macOS, 2026-09-17) |
| Docs | <https://developers.openai.com/codex/cli> |
| Herdr | session-identity integration → `codex resume <id>` |

## Flags the wrappers use (verified)

| Flag | Meaning |
| --- | --- |
| `--dangerously-bypass-approvals-and-sandbox` | no prompts, no sandbox — the point of `codexx` |
| `-p, --profile <name>` | load `~/.codex/<name>.config.toml` as an overlay on `config.toml` |
| `resume --last` | continue the most recent session |
| `resume <id>` / `resume --all` | resume by id / open the picker across all directories |
| `-m, --model <model>` | model for this launch |
| `-c model_reasoning_effort=<none\|low\|medium\|high\|xhigh>` | reasoning effort |

## Wrappers

```bash
codexx                  # codex --dangerously-bypass-approvals-and-sandbox
codexx -c | -l          # codex resume --last …
codexx -r [id]          # codex resume <id> …   |   codex resume --all …
codex-azure | codex-xai | codex-glm     # the same, with -p <provider>
```

Each provider wrapper first runs `lib/write_codex_profile.py`, which rewrites the
kit-owned overlay:

```toml
# ~/.codex/glm.config.toml — generated; do not hand-edit.
model = "glm-4.6"
model_provider = "ZAI"
[model_providers.ZAI]
name = "Z.AI GLM Coding Plan"
base_url = "https://api.z.ai/api/v1"
env_key = "ZAI_CODING_API_KEY"
wire_api = "responses"
```

`env_key` means Codex reads the value from the environment, which the wrapper
exported from your env file. Nothing secret lands on disk.

| Wrapper | profile | base URL | default model |
| --- | --- | --- | --- |
| `codex-azure` | `azure` | `AZURE_OPENAI_BASE_URL`, or built from `AZURE_OPENAI_RESOURCE` | `AZURE_OPENAI_DEFAULT_MODEL` → `AZURE_OPENAI_MODEL_DAILY` (required) |
| `codex-xai` | `xai` | `XAI_BASE_URL` (default `https://api.x.ai/v1`) | `XAI_DEFAULT_MODEL` → `XAI_MODEL_DAILY` |
| `codex-glm` | `glm` (provider id `ZAI`) | `ZAI_CODEX_BASE_URL` (default `https://api.z.ai/api/v1`) | `ZAI_CODEX_DEFAULT_MODEL` → `ZAI_DEFAULT_SONNET_MODEL` |

## Notes

- `CODEX_HOME` moves where the overlay is written; the wrappers honour it.
- The overlay is rewritten on every launch. Put your own settings in
  `config.toml`, not in the generated file.
- Whether a given third-party endpoint supports the Responses wire API is the
  provider's business, not the CLI's — if a provider variant returns a protocol
  error, check the provider's documented API shape first.
