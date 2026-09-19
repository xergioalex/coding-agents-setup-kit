# 7. Integrations

`herdr integration install <agent>` writes hooks or plugins into that agent's own
configuration so Herdr gets better signal than screen-scraping can give it.
There are two kinds:

| Type | What you get |
| --- | --- |
| **Lifecycle authority** | hook or plugin events author the `idle` / `working` / `blocked` state directly; screen detection is not used while the integration reports |
| **Session identity** | a native session id, so a pane can be restored after a server restart (`--resume <id>` / `--session <id>`); state still comes from screen detection |

Which agent falls in which group changes as Herdr adds support, and each
integration has a minimum version for native restore. `herdr integration status`
is the authority on your machine; the official page is the authority in general.

Relevant to this kit:

```bash
herdr integration install claude       # native session restore → claude --resume <id>
herdr integration install codex        # → codex resume <id>
herdr integration install cursor       # → cursor-agent --resume <id>
herdr integration install opencode     # lifecycle plugin + → opencode --session <id>
herdr integration install pi           # lifecycle hooks + → pi --session <id>
herdr integration install grok         # → grok --resume <id>
herdr integration status               # installed versions; reinstall when a newer minimum is listed
herdr integration uninstall <agent>
```

Install them **on the machine where the agent actually runs**: your own machine
for this kit's wrappers, the container or remote host for a remote session. They
edit that agent's configuration, so **ask the human first** — this kit's
onboarding reports them and never installs them for you.

## Wrappers and detection

Herdr detects the foreground process in the pane. Because every Unix wrapper here
ends with `exec`, the wrapper disappears and the CLI is what Herdr sees:

| You type | Herdr shows |
| --- | --- |
| `claudex`, `claude-glm` | Claude Code |
| `codexx`, `codex-glm`, `codex-azure`, `codex-xai` | Codex |
| `cursorx` | Cursor Agent |
| `opencodex`, `opencode-*` | OpenCode |
| `pix`, `pi-*` | Pi |
| `clinex`, `cline-*` | Cline |
| `grokx` | Grok |

A wrapper that does **not** exec (a sandbox launcher, a Windows `.cmd` shim, a
`docker exec` indirection) can hide the process. Label that one command:

```bash
HERDR_AGENT=codex my-sandbox-wrapper
```

## When the state looks wrong

```bash
herdr agent explain <target> --json     # which manifest rule matched, and the fallback reason
herdr server update-agent-manifests     # fetch manifest updates without restarting
```

An agent Herdr does not know still runs perfectly — it just shows `unknown`
until a manifest or the socket API tells it otherwise.

Official pages: <https://herdr.dev/docs/integrations/> · <https://herdr.dev/docs/agents/>
