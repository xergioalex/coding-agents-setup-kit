# 1. Concepts

Learn these in this order; almost every confusion later is one of them missing.

| Concept | Meaning | CLI handle |
| --- | --- | --- |
| **Server / client** | A background server owns the terminal processes; clients attach to render them. Detaching, closing the window or losing SSH does not stop the server. | `herdr status server` / `herdr status client` |
| **Session** | A persistent server namespace. Plain `herdr` uses the default session; named sessions are fully separate servers that share only the config file. Most people need only the default. | `herdr session list\|attach\|stop\|delete` |
| **Machine** | A saved SSH connection profile: opaque id, label, SSH target, remote session, enabled flag. Each machine has its own server, sessions and processes; losing one does not affect the others. `Local` is always present. | `herdr machine list\|add\|rename\|enable\|disable\|remove` |
| **Workspace** | The project-level container — one per repo, task or investigation. Owns tabs and panes; the sidebar rolls agent state up per workspace. Id `w1`. | `herdr workspace list\|create\|get\|focus\|rename\|close` |
| **Tab** | A layout inside a workspace. Id `w1:t1`. | `herdr tab …` |
| **Pane** | A real terminal. Split right or down. Id `w1:p1`. Survives client detach. | `herdr pane split\|run\|read\|wait-output\|…` |
| **Agent** | A process Herdr recognises inside a pane (Claude Code, Codex, Cursor Agent, OpenCode, Pi, Grok, Cline and more). States: `working`, `blocked` (an approval or question is on screen), `done` (idle, not yet seen), `idle`, `unknown`. May carry a unique name. | `herdr agent list\|get\|start\|prompt\|wait\|read\|send-keys\|explain` |
| **Integration** | Per-agent hooks or plugins Herdr installs into the agent's own config, so it can report lifecycle state and/or a native session id for restore. | `herdr integration install\|uninstall\|status` |
| **Modes** | *terminal* mode sends keys to the focused pane; *prefix* mode (`ctrl+b`, release, one key) sends one command to Herdr; *navigate* mode is a persistent navigation surface. The mouse covers everything; keybindings are optional. | `prefix+?` lists the live bindings |

Two properties that matter when you script it:

- **Ids are opaque and stable**, closed ids are never reused, and a pane moved to
  another workspace gets a new id.
- **Ids and agent names are scoped to one server.** Two machines can both have a
  `w1:p1` and both have an agent named `reviewer`. Always say which machine.

Inside a Herdr pane the environment carries `HERDR_ENV=1`,
`HERDR_WORKSPACE_ID`, `HERDR_TAB_ID`, `HERDR_PANE_ID`. An agent should check
`HERDR_ENV=1` before issuing any control command —
see [`06-agent-automation.md`](06-agent-automation.md).

Herdr is **not** tmux: there is no `.tmux.conf` and no tmux commands. It can run
*inside* tmux as the outer terminal, but a tmux started inside a pane hides the
agent from detection.

Official page: <https://herdr.dev/docs/concepts/>
