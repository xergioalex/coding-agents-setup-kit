# Herdr

[Herdr](https://herdr.dev) is a terminal workspace manager: a background
**server** owns your terminal processes and **clients** attach to render them, so
detaching, closing the window or losing an SSH connection never kills the work.
It also *recognises coding agents* inside panes and rolls their state up — which
is why it pairs so well with this kit.

This kit does not wrap Herdr. It installs the official client when it is missing
and documents it here, honestly, with the official page linked from every section.

| Page | What it covers |
| --- | --- |
| [`01-concepts.md`](01-concepts.md) | Server, session, machine, workspace, tab, pane, agent, integration, modes — learn them in this order |
| [`02-install-and-update.md`](02-install-and-update.md) | Install paths per OS, verification, update semantics, config file, logs, the agent skill |
| [`03-local-usage.md`](03-local-usage.md) | The daily loop, named sessions, direct attach, configuration, what survives what |
| [`04-machines-and-ssh.md`](04-machines-and-ssh.md) | The three ways to reach a remote Herdr, saved machines, Attention, driving a remote from scripts |
| [`05-container-setup.md`](05-container-setup.md) | Making a Docker container Herdr-ready: sshd, host keys, `allow_nested`, `new_cwd`, verification |
| [`06-agent-automation.md`](06-agent-automation.md) | Driving agents from scripts or from another agent: layout, pane and agent primitives, recipes, safety rules |
| [`07-integrations.md`](07-integrations.md) | Per-agent hooks and session restore, and how wrappers affect detection |
| [`08-troubleshooting.md`](08-troubleshooting.md) | Symptom → cause → fix |
| [`09-agent-to-agent.md`](09-agent-to-agent.md) | One agent delegating to, waiting for and reading back from another: the Herdr skill, the delegation loop, patterns, protocol rules, cross-machine |
| [`10-tailscale-and-termius.md`](10-tailscale-and-termius.md) | Reaching Herdr from a laptop or phone over a tailnet: OpenSSH vs Tailscale SSH, MagicDNS, saved machines, Termius setup, security |
| [`11-cloudflare-tunnel-and-termius.md`](11-cloudflare-tunnel-and-termius.md) | Verified recipe: phone (Termius) to a host's sshd through a Cloudflare Tunnel — CIDR route to a loopback alias, Allow/Block policies, a per-user device profile, keys-only sshd; why private hostname routes loop |
| [`12-cloudflare-mesh-and-termius.md`](12-cloudflare-mesh-and-termius.md) | Alternative, unverified: a hub driving Windows and Raspberry Pi nodes over Cloudflare Mesh, Termius to all of them, closing the LAN bypass |

Managing the machines themselves — starting the container, keeping its saved
machine enabled — is [`../machines.md`](../machines.md) (`agentbox`).

> **How to read these pages.** They were written against Herdr **0.9.x** and the
> official documentation. The installed binary's `herdr --help` and its
> subcommand help are always the authority for syntax: if they disagree with a
> page here, the binary wins and the page is a bug worth a pull request.
