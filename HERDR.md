# Herdr

[Herdr](https://herdr.dev) is a terminal workspace manager: a background server
owns your terminal processes, clients attach to render them, and it recognises
the coding agents running inside its panes. Detaching, closing the window or
losing SSH never kills the work.

This kit installs the official client when it is missing (`./install.sh --clis`)
and documents it — it does not wrap it.

**The full guide is [`docs/herdr/`](docs/herdr/README.md):**

| Page | What you need it for |
| --- | --- |
| [Concepts](docs/herdr/01-concepts.md) | server, session, machine, workspace, tab, pane, agent — in the order that makes them click |
| [Install and update](docs/herdr/02-install-and-update.md) | per OS, plus the update semantics that surprise people |
| [Local usage](docs/herdr/03-local-usage.md) | the daily loop, named sessions, config, what survives a restart |
| [Machines and SSH](docs/herdr/04-machines-and-ssh.md) | the three ways to reach a remote, saved machines, Attention |
| [Container setup](docs/herdr/05-container-setup.md) | making a Docker container Herdr-ready, end to end |
| [Agent automation](docs/herdr/06-agent-automation.md) | driving agents from scripts or from another agent |
| [Integrations](docs/herdr/07-integrations.md) | lifecycle hooks, native session restore, and how wrappers affect detection |
| [Troubleshooting](docs/herdr/08-troubleshooting.md) | symptom → cause → fix |

Managing the machines themselves — starting the container, keeping its saved
machine in step — is [`agentbox`](docs/machines.md).

Quick start:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
herdr --version && herdr status
cd ~/src/some-repo && herdr        # then run claudex / codexx / cursorx in a pane
# detach with ctrl+b q — everything keeps running
```
