# 4. Connecting machines over SSH

Three ways to reach a remote Herdr. Pick by workflow, not by taste:

| Path | Command | When |
| --- | --- | --- |
| tmux-style | `ssh host` then `herdr` | you already live in an SSH shell, or you are on a phone SSH client |
| remote attach | `herdr --remote <ssh-alias>` | you want your local UI (theme, keys, clipboard) on one remote session |
| saved machines | `herdr machine add <ssh-alias> --label "…"`, then `herdr` | Local plus several machines in **one** window, with shared agent navigation |

**Prerequisite for the last two: plain OpenSSH must work first.** `ssh <alias>`
has to succeed non-interactively — load the key into your agent (`ssh-add`) if it
has a passphrase. Herdr stores no passwords and no keys; authentication stays
with OpenSSH.

## SSH aliases

```sshconfig
Host devbox
  HostName 127.0.0.1          # for a container on this machine — never `localhost` (IPv6 ::1 may hit another listener)
  Port 22029
  User dev
  StrictHostKeyChecking accept-new
```

Targets can also be written `ssh://you@server:2222`. Do **not** set
`UserKnownHostsFile /dev/null`: saved-machine connections use strict host-key
checking and such a machine will sit in *Attention* forever.

`agentbox ssh-config --write` generates these blocks from your machines file —
see [`../machines.md`](../machines.md).

## Remote attach

```bash
herdr --remote devbox
herdr --remote devbox --session agents          # a named remote session
herdr --remote devbox --remote-keybindings server
herdr --remote devbox --handoff                 # experimental, when a server replacement is needed
```

What happens: Herdr looks for a compatible `herdr` on the remote PATH (then in
common install directories), **asks** before installing or updating one, starts
the remote background server and bridges it. By default it runs through a
temporary SSH config that includes yours and adds keepalives;
`[remote] manage_ssh_config = false` uses plain `ssh` instead.

## Saved machines

```bash
herdr machine add devbox --label "Dev box"
herdr machine add devbox --label "Dev box" --remote-session agents
herdr machine list [--json]              # read ids from here; never guess one
herdr machine rename <id> --label "New"
herdr machine disable <id> | enable <id> | remove <id>    # disconnects only; the remote keeps running
```

Behaviour worth knowing:

- Run `machine add` in an **interactive terminal**: it checks the remote binary
  and the server's capabilities and asks before installing or replacing anything
  (default No). A cancelled or failed setup saves nothing.
- Added and enabled machines connect in the background within about a second. A
  lost connection shows the last state **dimmed** — cached, not live — and
  retries with growing back-off.
- **Attention** means something needs a foreground answer: host key, passphrase,
  MFA, an install, an incompatible server. Fix it by running the command Herdr
  prints — usually `herdr --remote <target>` (plus `--session <name>`) — then
  restart the client. Background connections never answer prompts and never
  install, update or restart a server.
- Saved-machine connections need the remote server's `surface_interest` and
  `health_check` capabilities; older servers show Attention until updated.
- The catalog lives in the client state directory as `endpoints.json`: id, label,
  target, session, enabled — **no secrets**.

A machine's **label can be renamed; its target cannot.** If the target and your
SSH alias are spelled differently, remove the machine and add it again.

## Driving a remote from scripts: `--machine`

```bash
herdr --machine "Dev box" agent list
herdr --machine <id> pane list
herdr --machine "Dev box" agent prompt w1:p1 "run the tests"
```

This routes the JSON API over non-interactive SSH using the saved profile: no
TUI, and it never installs or restarts anything. Supported: `workspace`,
`worktree`, `tab`, `pane`, `notification`, `agent` (except `attach`),
`api snapshot`, `status server`, `server …`. Not forwarded: local install and
config commands, session management, interactive attach.

Remote ids are explicit — `--current` can never mean your local pane — remote
paths must be absolute or `~`-rooted, and `--machine` cannot be combined with
`--session` or `--remote`.

## Nesting

A machine you attach to *from a pane that is itself inside Herdr* needs
`[experimental] allow_nested = true` on the **server** side. On your own machine
you normally attach to a saved machine rather than nesting; nesting `--remote`
inside a local pane gives you two sidebars.

Official pages: <https://herdr.dev/docs/connecting-machines/> · <https://herdr.dev/docs/cli-reference/>
