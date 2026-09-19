# Cursor Agent CLI (`cursor-agent` / `agent`)

| | |
| --- | --- |
| Install (macOS/Linux) | `curl -fsSL https://cursor.com/install \| bash` |
| Install (Windows) | check the vendor's page — this kit has **no verified native Windows installer** for it and says so rather than guessing |
| Auth | `cursor-agent login`, or the first run |
| Verified against | the official CLI parameters reference (<https://cursor.com/docs/cli>), 2026-09-17 — **unverified on host** |
| Herdr | session-identity integration → `cursor-agent --resume <id>` |

## The `agent` name collision

Cursor's installer creates **both** `agent` and `cursor-agent`. The xAI Grok CLI
installer **also** creates an `agent`. So:

- `command -v agent` (or `where.exe agent`) is never proof that Cursor is installed;
- installing one after the other silently changes which one wins;
- a naive wrapper can launch Grok while telling you it launched Cursor.

This kit therefore never trusts `agent` alone. The resolver
(`agentkit_cursor_bin` in `lib/common.sh`, `Resolve-CursorBin` in
`win/lib/AgentKit.psm1`):

1. prefers the unambiguous `cursor-agent` name;
2. rejects any candidate whose resolved path is inside the Grok install tree or
   whose `--version` banner starts with `grok`;
3. falls back to the newest binary in Cursor's own versioned install directory;
4. and `agentkit status` prints a note when the `agent` on your PATH is Grok.

`tests/run.sh resolver` proves all four against fake binaries.

## Flags the wrapper uses (from the official reference)

| Flag | Meaning |
| --- | --- |
| `-f, --force` | force-allow commands unless explicitly denied (alias `--yolo`) — full permissions |
| `--continue` | continue the previous session |
| `--resume [chatId]` | resume a chat by id, or the picker |
| `ls` | list sessions |
| `--sandbox enabled\|disabled` | sandbox mode |
| `--model <model>` | model for this launch |

## Wrapper

```bash
cursorx                 # <resolved cursor-agent> --force
cursorx -c              # + --continue
cursorx -r [id]         # --resume=<id> --force   |   --resume --force
cursorx -l              # ls
CURSORX_SANDBOX=disabled cursorx     # adds --sandbox disabled
```

## Notes

- If `cursorx` says "Cursor Agent CLI not found", install Cursor's CLI even if
  `agent --version` prints something — that something is Grok.
- Cursor's desktop app listens on `127.0.0.1:2222` on some systems. Do not
  publish a container's SSH on that port; pick a free one and check first
  (see [`../herdr/05-container-setup.md`](../herdr/05-container-setup.md)).
