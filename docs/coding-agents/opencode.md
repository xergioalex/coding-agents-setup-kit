# OpenCode (`opencode`)

| | |
| --- | --- |
| Install (macOS/Linux) | `curl -fsSL https://opencode.ai/install \| bash` |
| Install (Windows) | `npm install -g opencode-ai` — verified (Windows 11, Windows PowerShell 5.1, 2026-10-03; OpenCode 1.18.34). npm's `allowScripts` policy may skip the package's `postinstall`; the CLI still ran. The vendor also documents Scoop and Chocolatey, and recommends WSL for the best experience |
| Auth | `opencode providers` for built-in providers; custom providers live in `opencode.json` |
| Config | `~/.config/opencode/opencode.json` (`%APPDATA%\opencode\opencode.json`) is **yours**; the kit merges one provider block. `OPENCODE_CONFIG` overrides the path |
| Verified against | OpenCode **1.18.30** (`opencode --help`, macOS, 2026-09-17) |
| Docs | <https://opencode.ai/docs> |
| Herdr | lifecycle plugin + session restore → `opencode --session <id>` |

## Flags the wrappers use (verified)

| Flag | Meaning |
| --- | --- |
| `--auto` | auto-approve permissions not explicitly denied |
| `-m, --model provider/model` | model for this launch — how the provider wrappers select a model **without** touching your global default |
| `-c, --continue`, `-s, --session <id>` | continue / resume (passed through) |
| `--variant <level>` | provider-specific reasoning effort |

## Wrappers

```bash
opencodex                                     # opencode --auto
opencode-azure | opencode-xai | opencode-glm  # merge the provider, then opencode --auto -m <provider>/<model>
```

What `lib/write_opencode_provider.py` does to your `opencode.json`:

```json
{
  "provider": {
    "ollama": { "…": "your existing providers are kept exactly as they were" },
    "xai": {
      "options": { "apiKey": "{env:XAI_API_KEY}", "baseURL": "https://api.x.ai/v1" },
      "whitelist": ["<daily>", "<reasoning>"],
      "models": {
        "<daily>": { "id": "<daily>", "name": "<daily>", "attachment": true,
                     "modalities": { "input": ["text", "image"], "output": ["text"] } }
      }
    }
  },
  "model": "ollama/x   ← untouched"
}
```

- `{env:KEY}` is resolved by OpenCode at runtime from the environment the
  wrapper exported. The raw key never lands in the file.
- Your global `model`, your other providers, your plugins and every other key
  are preserved. The first run keeps `opencode.json.agentkit.bak`.
- Invalid JSON aborts the wrapper with a message instead of overwriting.

| Wrapper | provider id | base URL | whitelisted models | default |
| --- | --- | --- | --- | --- |
| `opencode-azure` | `azure` | Azure base URL (see [providers](providers.md)) | `AZURE_OPENAI_MODEL_DAILY`, `_REASONING` | `AZURE_OPENAI_DEFAULT_MODEL` → daily |
| `opencode-xai` | `xai` | `XAI_BASE_URL` | `XAI_MODEL_DAILY`, `_REASONING` | `XAI_DEFAULT_MODEL` → daily |
| `opencode-glm` | `zai-coding-plan` | `ZAI_CODING_BASE_URL` | sonnet, opus, haiku | `ZAI_OPENCODE_DEFAULT_MODEL` → sonnet |

`opencode-glm` also exports `ZHIPU_API_KEY` and `ZAI_API_KEY` for its process,
because some builds look for one of those names.

## Notes

- `opencode.json` is strict JSON. A config with comments will be refused by the
  writer — that is the writer being careful, not a bug.
- Nothing in the kit ever sets the global `model`: a wrapper that did would
  silently change what plain `opencode` does.
