# Documentation index

This repository installs the terminal coding agents, wraps them in one uniform
command surface, and documents how to run them — including inside Herdr.
`docs/` is the reference layer; [`AGENTS.md`](../AGENTS.md) is the compact entry
point for an AI agent working on the repo itself.

## Start here

| Task | Read |
| --- | --- |
| Install the kit (human) | [`../INSTALL.md`](../INSTALL.md) |
| Install the kit (hand this to an agent) | [`../AGENT_BOOTSTRAP.md`](../AGENT_BOOTSTRAP.md) |
| Understand what this repo is for | [`PRODUCT_SPEC.md`](PRODUCT_SPEC.md) |
| Windows specifics | [`WINDOWS.md`](WINDOWS.md) |
| Change a wrapper or a writer | [`ARCHITECTURE.md`](ARCHITECTURE.md), [`STANDARDS.md`](STANDARDS.md), [`TESTING_GUIDE.md`](TESTING_GUIDE.md) |
| Per-CLI install, auth, flags, providers | [`coding-agents/README.md`](coding-agents/README.md) |
| Install and drive Herdr, connect machines | [`herdr/README.md`](herdr/README.md) |
| Manage the boxes you run agents on | [`machines.md`](machines.md) |
| Pick the right model and reasoning effort | [`model-strategy/README.md`](model-strategy/README.md) |

## Canonical guides

| Guide | What it covers |
| --- | --- |
| [`PRODUCT_SPEC.md`](PRODUCT_SPEC.md) | Problem, users, deliverables, success criteria, non-goals |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | wrapper → lib → CLI flow, where state lives on each OS, key decisions |
| [`STANDARDS.md`](STANDARDS.md) | Bash / PowerShell / Python conventions, naming, the session-flag contract, hard rules |
| [`TESTING_GUIDE.md`](TESTING_GUIDE.md) | The gate, scoped runs, source→test mapping, blind spots |
| [`DEVELOPMENT_COMMANDS.md`](DEVELOPMENT_COMMANDS.md) | Verbatim commands: validate, try, install, doctor |
| [`SECURITY.md`](SECURITY.md) | Where secrets live, what the writers may put on disk, installer posture, the Cline exception |
| [`PERFORMANCE.md`](PERFORMANCE.md) | Startup cost of a wrapper; why the writers run on every launch |
| [`WINDOWS.md`](WINDOWS.md) | Native vs WSL, PATH, Execution Policy, Mark-of-the-Web, encodings, what is verified |
| [`machines.md`](machines.md) | `agentbox`: machines file, verbs, the Herdr lifecycle, ssh config generation |
| [`DEEP_WORK_PLANS.md`](DEEP_WORK_PLANS.md) | The plan convention this repo uses for structured agent work |
| [`AI_AGENT_ONBOARDING.md`](AI_AGENT_ONBOARDING.md) | First-session checklist for an agent changing this kit |
| [`AI_AGENT_COLLAB.md`](AI_AGENT_COLLAB.md) | Ownership, handoffs, what only a human decides |

## Topic guides

| Folder | What it covers |
| --- | --- |
| [`coding-agents/`](coding-agents/README.md) | One page per CLI (Claude Code, Codex, Cursor Agent, OpenCode, Pi, Cline, Grok), the provider reference, and the wrapper table |
| [`herdr/`](herdr/README.md) | Concepts, install, local use, saved SSH machines, making a container reachable, driving agents from scripts, integrations, troubleshooting |
| [`model-strategy/`](model-strategy/README.md) | Which model and reasoning effort a task deserves, and the flag that reaches it in each CLI |

## Verification legend

Used throughout the per-CLI and Herdr pages:

- **verified** — checked against the named installed version or the vendor's
  official reference, with the date.
- **unverified on host** — carried over from another platform or another
  machine. Run `<cli> --help` before relying on it, then update the page.

A claim with no version and no link is a bug in this documentation.
