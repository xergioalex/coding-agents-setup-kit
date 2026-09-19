# 6. Agent automation

Driving agents from a script, or from another agent. Herdr exposes three
primitives over the CLI and socket API. Most control commands print JSON —
**read ids from the response, never predict them**.

| Primitive | Responsibility | Commands |
| --- | --- | --- |
| Layout | create and organise terminal locations | `workspace create\|list\|get\|focus\|rename\|close`, `tab create\|list`, `pane split\|move\|layout\|list\|current` |
| Pane | raw terminal control | `pane run`, `pane send-text`, `pane send-keys`, `pane read`, `pane wait-output` |
| Agent | the recognised coding agent in a pane, by name or pane id | `agent start\|prompt\|wait\|read\|send-keys\|get\|rename\|focus\|list\|explain\|attach` |

## Preconditions for an agent issuing commands

```bash
test "${HERDR_ENV:-}" = 1 || { echo "not inside a Herdr pane"; exit 1; }
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
herdr --help; herdr agent; herdr pane      # the installed binary is the syntax authority
```

Do **not** run bare `herdr` for discovery — it attaches the TUI. Do **not** probe
a mutating command by omitting arguments: `herdr workspace create` runs with
defaults.

## Recipe: start a helper agent next to you and wait for it

```bash
split=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus)
pane=$(printf '%s\n' "$split" | jq -r '.result.pane.pane_id')
herdr agent start reviewer --kind codex --pane "$pane" -- -m <model>   # args after -- go to the CLI
herdr agent prompt reviewer "Review the current diff and report only actionable findings." --wait --timeout 120000
herdr agent read reviewer --source recent-unwrapped --lines 120
```

- `--kind` takes the agent kinds Herdr knows (`herdr agent start --help` lists
  the current set — it includes claude, codex, cursor, opencode, pi, cline, grok
  and many others). Names must be unique and match `[a-z][a-z0-9_-]{0,31}`.
- `agent start` needs an **available shell pane** (prompt visible, nothing in the
  foreground); it never creates or splits layout. It returns when the agent is
  detected and ready, or `agent_not_ready` if it starts blocked — the name still
  works for `read` and `send-keys`.
- `agent prompt --wait` waits for the first settled `idle` / `done` / `blocked`.
  `agent_blocked` means it was already at an approval dialog: inspect it, ask the
  human, answer with `agent send-keys`.
- `agent_prompt_stalled` or a timeout do **not** prove the prompt was lost.
  `agent read` before resending, or you will double-submit.
- `--until blocked|idle|done|unknown` for state-specific waits.

**To launch one of this kit's wrappers** rather than the bare CLI, use the pane
surface and then ask what landed there:

```bash
herdr pane run "$pane" "codex-glm"
herdr agent get "$pane"
```

## Recipe: run a command elsewhere and watch its output

```bash
split=$(herdr pane split --current --direction down --cwd "$PWD" --no-focus)
pane=$(printf '%s\n' "$split" | jq -r '.result.pane.pane_id')
herdr pane run "$pane" "tests/run.sh"
herdr pane wait-output "$pane" --regex "passed: [0-9]+  failed: 0|FAIL" --timeout 120000
herdr pane read "$pane" --source recent-unwrapped --lines 120
```

Read sources: `visible` (viewport), `recent` (with soft wraps),
`recent-unwrapped` (best for logs), `detection` (the plain-text buffer used for
state). `--format ansi` when colours are the evidence. Full-screen agents keep
history on the alternate screen, so for long output it is cheaper to have the
agent write to a file and read the file.

## Remote machines

```bash
herdr --machine "Dev box" agent list
herdr --machine "Dev box" agent prompt w1:p1 "run the tests"
```

Ids are per server, and `--current` never refers to your local pane when
`--machine` is used.

## Safety rules

- `--no-focus` for background work. Address panes by explicit id or by a unique
  agent name — never "the focused pane": it may belong to the human or to
  another client.
- Do not close workspaces, tabs, panes or sessions you did not create, and do not
  bypass a "group close required" guard just to make a command succeed.
- Trust a repository only after the human has verified it.
- Never `herdr server stop` from an active session unless the human wants every
  pane process ended, and never kill the main Herdr process. Use a **named
  session** for experiments.
- Check `herdr status` after an update: client and server can differ, and a
  missing method is not permission to restart someone's server.
- Server errors are JSON on stderr with exit 1; CLI syntax errors exit 2.

## A note on wrappers and detection

Herdr identifies the **foreground process** in a pane. The Unix wrappers in this
kit `exec` the real CLI, so `claudex` is detected as Claude Code and `codex-glm`
as Codex. A wrapper that stays alive as a parent (the Windows `.cmd` shims) can
hide the process; label that command with `HERDR_AGENT=<kind>` — see
[`07-integrations.md`](07-integrations.md).

Official pages: <https://herdr.dev/docs/agent-automation/> · <https://herdr.dev/docs/socket-api/> · `herdr --skill`
