# xAI Grok CLI (`grok`)

| | |
| --- | --- |
| Install (macOS/Linux) | `curl -fsSL https://x.ai/cli/install.sh \| bash` — **not an npm package** |
| Install (Windows) | `irm https://x.ai/cli/install.ps1 \| iex` — verified (Windows 11, Windows PowerShell 5.1, 2026-10-03; grok 1.0.46). Installs `grok.exe` **and `agent.exe`** to `%USERPROFILE%\.grok\bin` and **prepends** that to the user `Path`, so `agent` resolves to Grok — see [`cursor-agent.md`](cursor-agent.md) |
| Auth | `grok login` (OAuth) → `~/.grok/auth.json`, **or** `XAI_API_KEY` |
| Update | `grok update [version]` |
| Verified against | grok **1.0.30** (`grok --help`, macOS, 2026-09-17) |
| Docs | <https://x.ai/cli> |
| Herdr | session-identity integration → `grok --resume <id>` |

## Flags the wrapper uses (verified)

| Flag | Meaning |
| --- | --- |
| `-c, --continue` | continue the most recent session |
| `-r, --resume [id-or-title]` | resume by id/title, or the most recent |
| `-m, --model <model>` | model for this launch (`grok models` lists them) |
| `--reasoning-effort <effort>` | reasoning effort (alias `--effort`) |

Grok has **no permission-bypass flag** in `--help`. `grokx` is therefore session
flags plus env loading — not a permission change. The kit does not pretend
otherwise.

## Wrapper

```bash
grokx                 # grok
grokx -c              # grok --continue
grokx -r [id]         # grok --resume [id]
```

`XAI_API_KEY` is **optional** here: if it is set it is exported for the process;
if neither the key nor `~/.grok/auth.json` exists, `grokx` warns
(`run 'grok login' or set XAI_API_KEY`) and still launches so Grok can show its
own login. `agentkit status` reports `grok login: present` when the auth file
exists.

The `*-xai` wrappers (`codex-xai`, `opencode-xai`, `pi-xai`, `cline-xai`) are
different: they talk to the xAI API directly and **require** `XAI_API_KEY`.

## The `agent` symlink

Grok installs an `agent` entry point too. It is **not** Cursor — see
[`cursor-agent.md`](cursor-agent.md) for how the kit tells them apart.
