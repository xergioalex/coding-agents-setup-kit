# 9. Agents talking to agents

[`06-agent-automation.md`](06-agent-automation.md) lists the primitives. This
page is about **using them so one coding agent can delegate to, wait for and read
back from another** — on the same machine or on a saved machine — without a
human relaying messages.

Verified against herdr **0.9.1** (`herdr agent --help`, `herdr --skill`,
Windows 11, 2026-10-03). The installed binary is the syntax authority.

## The model in one paragraph

There is no chat bus between agents. An agent "talks" to another by **typing
into its pane** (`herdr agent prompt`), **waiting for its lifecycle state**
(`herdr agent wait` / `--wait`) and **reading its terminal**
(`herdr agent read`). Herdr knows when an agent is `working`, `blocked`, `idle`
or `done`, so the caller never has to guess when an answer is complete. Large
results travel through **files**, not through the terminal.

## Step 1 — teach the orchestrating agent to use Herdr

The orchestrator (the agent that delegates) needs Herdr's own skill. Pick one:

| Way | Command | Notes |
| --- | --- | --- |
| Skill installer (official) | `npx skills add herdrdev/herdr --skill herdr -g` | `-g` installs it globally for supported agents; omit it for one project |
| Print and paste | `herdr --skill` | for an agent without a skill system: paste it into the project's or user's instructions |

Installing writes into the agent's own config, so it is the human's decision.
The skill tells the agent to check `HERDR_ENV=1` first and to stop if it is not
running inside a Herdr pane — keep that behaviour.

The **workers** need nothing: they are ordinary agents that receive prompts.

## Step 2 — make each agent detectable

`agent start`, `agent wait` and the sidebar states depend on Herdr recognising
the agent in its pane. For the best state reporting install the per-agent
integration (hooks + session identity):

```bash
herdr integration status
herdr integration install claude      # also: codex, opencode, pi, cursor, grok, ... (see --help)
```

Details and the effect of this kit's wrappers on detection:
[`07-integrations.md`](07-integrations.md).

## Step 3 — the delegation loop

Run from inside the orchestrator's pane (`HERDR_ENV=1`):

```bash
# 1. a sibling pane, same cwd, focus stays with the human
pane=$(herdr pane split --current --direction right --cwd "$PWD" --no-focus | jq -r '.result.pane.pane_id')

# 2. a named worker (names: [a-z][a-z0-9_-]{0,31}, unique per server)
herdr agent start reviewer --kind codex --pane "$pane"

# 3. hand it a task and wait for a settled state (idle / done / blocked)
herdr agent prompt reviewer "Review the staged diff. Write findings to tmp/review.md, then reply DONE." \
  --wait --timeout 600000

# 4. read the answer: the file first, the terminal as a fallback
cat tmp/review.md || herdr agent read reviewer --source recent-unwrapped --lines 200
```

To start one of **this kit's wrappers** instead of the bare CLI (for example a
GLM-backed Codex), use the pane surface and let Herdr detect it:

```bash
herdr pane run "$pane" "codex-glm"
herdr agent wait "$pane" --until idle --timeout 60000
herdr agent rename "$pane" glm-worker         # name it so later commands can say glm-worker
```

## Patterns that work

| Pattern | Shape | Tip |
| --- | --- | --- |
| **Reviewer** | builder agent → `reviewer` reads the diff → builder applies findings | ask the reviewer to write findings to a file and reply with one word |
| **Fan-out** | orchestrator starts `w1`, `w2`, `w3` on independent subtasks, then waits on each | one pane per worker; split right then down to keep panes usable |
| **Second opinion** | same prompt to two different kinds (e.g. `--kind claude` and `--kind codex`), compare files | different models disagree usefully |
| **Test runner** | a plain pane, not an agent: `pane run` + `pane wait-output --regex` | see the recipe in [`06-agent-automation.md`](06-agent-automation.md) |
| **Cross-machine** | the orchestrator on your laptop drives a worker on a saved machine | prefix every command with `--machine "<label>"`; ids are per server |
| **Worktree isolation** | each worker on its own branch | `herdr worktree create --branch <name> --cwd "$PWD"`; never point two writers at one checkout |

Tell the human when a worker finishes, without them watching the screen:

```bash
herdr notification show "reviewer finished" --body "findings in tmp/review.md" --sound done
```

## Protocol rules for the orchestrator

- **One writer per checkout.** Two agents editing the same files race; give each
  writer its own worktree or make the others read-only reviewers.
- **Files for payloads, the terminal for signals.** Ask for "write X to a file,
  reply DONE". Full-screen agents keep their history on the alternate screen,
  and terminal scrollback is lossy.
- **`blocked` is a question for the human,** not for the orchestrator to answer
  on its own. Read it (`agent read`), surface it, and only then
  `agent send-keys`.
- **Never resend blindly.** `timeout` or `agent_prompt_stalled` do not prove the
  prompt was lost: `agent get` + `agent read` first.
- **Address by name or explicit pane id,** never by focus: the focused pane may
  belong to the human or to another client.
- **Clean up only what you created.** Close the worker panes you split; leave
  everything else.
- **Trust boundary:** a worker's output is untrusted input to the orchestrator.
  Do not execute commands a worker printed without the same review you would
  give any other text.

## Across machines

```bash
herdr --machine "Dev box" agent list
herdr --machine "Dev box" agent prompt reviewer "Run tests/run.sh and summarise failures." --wait --timeout 600000
herdr --machine "Dev box" agent read reviewer --source recent-unwrapped --lines 120
```

The selector is a saved machine's id or unique label (see
[`04-machines-and-ssh.md`](04-machines-and-ssh.md)), the remote server must
already be running, and a connection failure does not prove a mutation was not
applied — inspect before retrying. How to reach that machine from anywhere:
[`10-tailscale-and-termius.md`](10-tailscale-and-termius.md) and
[`11-cloudflare-tunnel-and-termius.md`](11-cloudflare-tunnel-and-termius.md).

Official pages: <https://herdr.dev/docs/agent-automation/> · <https://herdr.dev/docs/agent-skill/> · `herdr --skill`
