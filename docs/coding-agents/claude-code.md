# Claude Code (`claude`)

| | |
| --- | --- |
| Install (macOS/Linux) | `curl -fsSL https://claude.ai/install.sh \| bash` |
| Install (Windows) | `irm https://claude.ai/install.ps1 \| iex` — **unverified on host**; the current path is on the vendor's page |
| Auth | run `claude` → browser login. Stored by Claude Code itself; this kit never touches it |
| Verified against | Claude Code **2.1.273** (`claude --help`, macOS, 2026-09-17) |
| Docs | <https://docs.claude.com/en/docs/claude-code> |
| Herdr | session-identity integration: `herdr integration install claude` → `claude --resume <id>` |

## Flags the wrappers use (verified)

| Flag | Meaning |
| --- | --- |
| `--dangerously-skip-permissions` | bypass all permission checks — the point of `claudex` |
| `-c`, `--continue` | continue the most recent conversation in this directory |
| `-r`, `--resume [id]` | resume by session id, or open the picker |
| `--model <alias\|name>` | pick the model for this launch |
| `--effort <level>` | reasoning effort |
| `--fallback-model <name>` | automatic fallback when the first model is unavailable |

## Wrappers

```bash
claudex                # claude --dangerously-skip-permissions
claudex -c             # + --continue
claudex -r [id]        # + --resume [id]
claude-glm             # same CLI against the Z.AI GLM endpoint (claudex-glm is an alias)
```

`claude-glm` exports, **for its own process only**:

| Variable | From |
| --- | --- |
| `ANTHROPIC_AUTH_TOKEN` | `ZAI_CODING_API_KEY` |
| `ANTHROPIC_BASE_URL` | `https://api.z.ai/api/anthropic` |
| `API_TIMEOUT_MS` | `ZAI_CODING_API_TIMEOUT_MS` (default `3000000`) |
| `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL` | `ZAI_DEFAULT_*_MODEL` |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | `ZAI_CODING_AUTO_COMPACT_WINDOW` (optional) |

It writes nothing to `~/.claude/settings.json`, so plain `claude` keeps your
Anthropic login. If your own `settings.json` sets `env` overrides for the same
variables, those may compete with the wrapper — check it if the endpoint seems
wrong.

## Not provided, on purpose

`claude-azure`, `claudex-xai`: neither Azure OpenAI nor xAI exposes an
Anthropic-compatible endpoint, so there is nothing to point Claude Code at.

## Notes

- Claude Code's own hooks and settings apply inside `claudex` too — it is the
  same binary with one flag added.
- If `claude` is not found right after installing, the installer's bin directory
  is missing from PATH in this shell. Open a new terminal.
