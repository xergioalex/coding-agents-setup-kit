# 3. Local usage

## The daily loop

```bash
cd ~/src/some-repo
herdr                      # launch or attach the default session; a workspace for this directory
# start an agent in the pane: claudex / codexx / cursorx / opencodex … (this kit's wrappers)
# detach: ctrl+b q, or just close the window — everything keeps running
herdr                      # reattach later, from anywhere
herdr server stop          # only when you really want every pane process ended
```

Mouse first: click panes and tabs to focus, drag the borders, right-click for
menus, drag-select to copy. Keyboard when you want it: prefix `ctrl+b`, then `v`
(split right), `-` (split down), `c` (new tab), `q` (detach), `w` (workspace
navigation), `?` (list the live bindings). The prefix and every binding are
configurable under `[keys]`.

## Named sessions

Independent servers for independent contexts — separate panes, separate sockets,
shared config file:

```bash
herdr session list [--json]
herdr session attach work          # or: herdr --session work
herdr session stop work
herdr session delete side-project  # exact name, case-sensitive
```

Use one for experiments, so a mistake never touches your main session.

## Direct terminal attach

Open one server-owned terminal in your current terminal, without the full UI:

```bash
herdr agent attach reviewer           # by agent name
herdr terminal attach <terminal-id>   # by id; --takeover to steal input
# detach: ctrl+b q       literal ctrl+b: ctrl+b ctrl+b
```

## Configuration

- File: `~/.config/herdr/config.toml` (`HERDR_CONFIG_PATH` overrides it).
- Print the defaults: `herdr --default-config`. Validate: `herdr config check`.
- Apply without restarting: `herdr server reload-config`.
- Reset custom keys: `herdr config reset-keys` (it backs up first).
- Areas: `[keys]`, `[theme]`, `[ui]`, `[terminal]`, `[update]`, `[remote]`,
  `[session]`, `[experimental]`.

Two settings worth considering:

```toml
[experimental]
allow_nested = true            # lets `herdr --remote` run from inside a Herdr pane

[remote]
manage_ssh_config = false      # use your ~/.ssh/config as-is instead of a generated temp one
```

## What survives what

| Case | Processes keep running | Layout returns | Agent conversation resumes |
| --- | --- | --- | --- |
| detach / reattach | yes | yes | yes (it never stopped) |
| server restart | **no** | yes (workspaces, tabs, panes, cwd) | only with native session restore (integration installed) |
| `herdr update` without handoff | compatible servers keep running | yes | via native restore after a restart |
| `herdr update --handoff` | best effort | yes | yes when the handoff succeeds |

Pane history replay after a restart is **off by default**, deliberately: pane
output can contain secrets. `[experimental] pane_history = true` opts in, and
then the Herdr state directory deserves the same care as your shell history.

## Where this kit's wrappers fit

A Herdr pane is an ordinary shell, so `claudex`, `codexx`, `cursorx`, … are on
PATH exactly as anywhere else once `install.sh` has run. In a remote session,
what is on that machine's PATH applies — which is why
[`05-container-setup.md`](05-container-setup.md) suggests installing the kit (or
at least the CLIs) inside the image.

Official pages: <https://herdr.dev/docs/quick-start/> · <https://herdr.dev/docs/how-to-work/> · <https://herdr.dev/docs/configuration/>
