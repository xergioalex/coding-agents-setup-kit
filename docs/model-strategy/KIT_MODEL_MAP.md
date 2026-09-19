# Kit ↔ model map

How the tiers in [`TIERS.md`](TIERS.md) reach the wrappers this kit installs, and
how to set model and reasoning effort in each CLI.

Flags marked **verified** were read from the installed CLI's `--help` on macOS,
2026-09-17 (Claude Code 2.1.273, Codex 0.144.4, OpenCode 1.18.30, Pi 0.85.1,
Grok 1.0.30). The rest come from the vendor's reference and are marked.

## 1. Which wrapper reaches which tier

| Tier | Anthropic (`claudex`) | OpenAI (`codexx`) | xAI (`grokx`, `*-xai`) | Z.AI (`*-glm`) | Azure (`*-azure`) | Cursor (`cursorx`) |
| --- | --- | --- | --- | --- | --- | --- |
| **Daily** | the fast Sonnet-class model | the fast coding model | `XAI_MODEL_DAILY` | `ZAI_DEFAULT_HAIKU_MODEL` | `AZURE_OPENAI_MODEL_DAILY` | Cursor's own fast model |
| **Reasoning** | `--model opus` (or the strongest available) | the strong general model | `XAI_MODEL_REASONING` | `ZAI_DEFAULT_SONNET_MODEL` / `_OPUS_MODEL` | `AZURE_OPENAI_MODEL_REASONING` | an external model selected in Cursor |
| **Super Reasoning** | the frontier model at high effort | the frontier model at high effort | reasoning model at `--effort xhigh` | the strongest GLM available | whatever you deployed for it | an external frontier model |

The `*_MODEL_DAILY` / `*_MODEL_REASONING` pairs in `env.example` **are** the
Daily/Reasoning split: the provider wrappers whitelist both, so you can switch
inside a session without relaunching. `*_DEFAULT_MODEL` picks which one a session
starts on — keep it on Daily and escalate on purpose.

Azure deployment names are yours. The kit requires `AZURE_OPENAI_MODEL_DAILY`
precisely because it cannot guess what you deployed or which tier it belongs to.

## 2. Model and effort controls per CLI

Three separate decisions: **provider** (which wrapper), **model** (flag or env),
**effort** (flag or config). Every wrapper forwards extra arguments verbatim, so
CLI flags go after the wrapper's own.

| CLI (wrapper) | Model | Reasoning effort | Status |
| --- | --- | --- | --- |
| Claude Code (`claudex`, `claude-glm`) | `--model <alias\|name>`; `/model` in session | `--effort <level>`; `--fallback-model` for automatic fallback | verified 2.1.273 |
| Codex (`codexx`, `codex-*`) | `-m, --model <model>`; provider wrappers set it from `*_DEFAULT_MODEL` | `-c model_reasoning_effort=<none\|low\|medium\|high\|xhigh>` | verified 0.144.4 |
| OpenCode (`opencodex`, `opencode-*`) | `-m provider/model` (a later `-m` wins over the wrapper's) | `--variant <level>` | verified 1.18.30 |
| Pi (`pix`, `pi-*`) | `--model <pattern>` (`provider/id`, optional `:<thinking>`); `--models a,b` for the cycle list | `--thinking <off\|minimal\|low\|medium\|high\|xhigh\|max>` | verified 0.85.1 |
| Grok (`grokx`) | `-m, --model <model>`; `grok models` lists them | `--reasoning-effort <effort>` (alias `--effort`) | verified 1.0.30 |
| Cursor Agent (`cursorx`) | `--model <model>` | model-level | vendor reference |
| Cline (`clinex`, `cline-*`) | `-m <model>` (provider wrappers pass `*_DEFAULT_MODEL`) | model-level | unverified on host |

Examples:

```bash
claudex                                   # Daily: default model, default effort
claudex --model opus --effort high        # Reasoning: hard debugging, architecture
codexx -c model_reasoning_effort=low      # Daily mechanical work, cheaper and faster
codex-xai -m "$XAI_MODEL_REASONING" -c model_reasoning_effort=high
grokx -m "$XAI_MODEL_REASONING" --effort xhigh
opencode-glm -m "zai-coding-plan/$ZAI_DEFAULT_HAIKU_MODEL"
opencode-glm --variant high               # push the current model's effort up
pi-xai --thinking high
```

## 3. Keeping this honest

- A flag that is not in the table above has not been verified here. Check
  `<cli> --help`, then add it **with the version you saw**.
- Refresh the model ids in your env file when a provider ships a new generation;
  nothing in the kit pins you to a specific one.
- If a wrapper starts on the wrong model, check the precedence:
  `*_DEFAULT_MODEL` → `*_MODEL_DAILY` → the kit's fallback, and any `-m` you pass
  wins over all of them.
