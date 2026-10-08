# Pi coding agent (`pi`)

| | |
| --- | --- |
| Install (any OS) | `npm install -g --ignore-scripts @earendil-works/pi-coding-agent` |
| Auth | Pi's own provider credentials; custom providers in `~/.pi/agent/models.json` |
| Config | `~/.pi/agent/` (`PI_CODING_AGENT_DIR`); `models.json` is **yours** — the kit upserts one provider. `PI_MODELS_FILE` overrides the path |
| Verified against | Pi **0.85.1** (`pi --help`, macOS, 2026-09-17) |
| Herdr | lifecycle hooks + session restore → `pi --session <id>` |

## Flags the wrappers use (verified)

| Flag | Meaning |
| --- | --- |
| `--approve`, `-a` | **trust project-local files for this run** (extensions, skills, prompt templates, `AGENTS.md` / `CLAUDE.md` found in the project). This is what "full permissions" means for Pi: its built-in `read`/`bash`/`edit`/`write` tools had no per-call approval flag in 0.85.1 — restrict them with `--tools` / `--exclude-tools` / `--no-tools` instead |
| `--provider <name>` | a provider registered in `models.json` |
| `--model <pattern>` | model pattern or id; supports `provider/id` and an optional `:<thinking>` suffix |
| `--models a,b,c` | the patterns available for in-session cycling |
| `--thinking <off\|minimal\|low\|medium\|high\|xhigh\|max>` | reasoning effort |
| `--continue`, `-c` / `--resume`, `-r` | continue / pick a session |
| `--print`, `-p` | non-interactive: process the prompt and exit |

## Wrappers

```bash
pix                          # pi --approve
pi-azure | pi-xai | pi-glm   # upsert the provider, then
                             # pi --approve --provider <id> --model <default> --models <list>
```

What `lib/write_pi_provider.py` upserts — `apiKey` is an env **reference**:

```json
{
  "providers": {
    "zai-glm": {
      "baseUrl": "https://api.z.ai/api/coding/paas/v4",
      "api": "openai-completions",
      "apiKey": "$ZAI_CODING_API_KEY",
      "compat": { "supportsDeveloperRole": false, "supportsReasoningEffort": false },
      "models": [
        { "id": "glm-5.3-flash", "name": "glm-5.3-flash (sonnet)", "reasoning": true,
          "input": ["text", "image"], "contextWindow": 200000, "maxTokens": 131072 }
      ]
    }
  }
}
```

| Wrapper | provider id | context / maxTokens / reasoning_effort | models |
| --- | --- | --- | --- |
| `pi-azure` | `azure-foundry` | 200000 / 32768 / true | daily, reasoning |
| `pi-xai` | `xai-grok` | 200000 / 32768 / true | daily, reasoning |
| `pi-glm` | `zai-glm` | 200000 / 131072 / false | sonnet, opus, haiku (deduped) |

Other providers already in `models.json` are preserved, invalid JSON aborts the
wrapper, and a one-time `models.json.agentkit.bak` is kept.

## Notes

- Skipping the `models.json` write would make `--provider` fail — that is why the
  wrapper writes before launching.
- Pi reads `AGENTS.md` / `CLAUDE.md` from the project by default
  (`--no-context-files` disables it).
- Context-window and max-token numbers above are the kit's defaults for the
  provider entry. If your plan differs, edit `models.json` — the writer only
  replaces the provider it owns, so your edit survives until the next launch of
  that wrapper. For a permanent change, set the values in your own provider entry
  under a different id and use `pix --provider <id>`.
