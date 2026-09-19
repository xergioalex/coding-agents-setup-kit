# Product spec

## The problem

A developer who wants to use several terminal coding agents — Claude Code,
OpenAI Codex, Cursor Agent, OpenCode, Pi, Cline, Grok — hits the same wall on
every new machine:

- each CLI has a different installer, and some of them only document one OS;
- each has a different flag for "stop asking me to approve every command";
- each stores sessions differently, so "continue where I left off" is a
  different incantation per tool;
- pointing any of them at a different provider (Z.AI GLM, xAI, Azure OpenAI)
  means hand-editing a config file, and the fastest way to do that is to paste
  the API key in — where it stays, in plain text, often inside a git repo.

Doing this by hand takes an afternoon per machine and ends differently every
time. Nobody writes down which flag was verified against which version, so the
setup rots quietly.

## Who it is for

- **A developer with more than one machine** (or more than one OS) who wants the
  same commands everywhere.
- **A team** that wants one reviewed way to install agents rather than seven
  personal ones.
- **An AI agent asked to "set up this machine"**: [`AGENT_BOOTSTRAP.md`](../AGENT_BOOTSTRAP.md)
  is a self-contained prompt, and [`AGENTS.md`](../AGENTS.md) plus `docs/` give
  it enough context to extend the kit safely.
- **Anyone connecting Herdr to containers or remote boxes** — the Herdr guides
  stand on their own, with no machine list baked in.

## What it delivers

1. **One install command** (`./install.sh --onboard`, or `.\install.ps1 -Onboard`)
   that detects what is already there, keeps it, installs only what is missing,
   and puts the wrapper set on PATH. Idempotent; safe to re-run.
2. **A uniform surface**: `claudex`, `codexx`, `cursorx`, `opencodex`, `pix`,
   `clinex`, `grokx`, plus the provider variants — as real executables, so they
   work from any shell, from a Herdr pane, and from a non-interactive agent session.
3. **Provider variants that never write secrets to disk**: Codex `env_key`,
   OpenCode `{env:KEY}`, Pi `"$KEY"` — the value stays in one env file with
   restrictive permissions.
4. **A doctor** (`agentkit status`) that reports CLIs, wrappers, PATH and which
   keys are set — by name, never by value.
5. **Herdr know-how**: install, sessions, saved SSH machines, making a container
   reachable, driving agents from scripts, integrations, troubleshooting.
6. **An optional machines command** (`agentbox`) driven by a file you write, so
   the containers you run agents on start, stop and stay in step with Herdr.

## Success criteria

- A fresh machine reaches `claudex`, `codexx`, `opencodex`, `grokx` on PATH from
  one command, with nothing reinstalled that was already present.
- A machine that already has Cursor, OpenCode, custom OpenCode/Codex configs and
  its own Herdr machines loses **nothing**: no global default rewritten, no
  config overwritten, no CLI moved.
- `tests/run.sh` is green and `agentkit status` never prints a secret.
- Every flag in the docs names the version it was verified against, or is
  labelled `unverified on host`.

## Non-goals

- Reimplementing Herdr. The official client is installed and documented.
- Shipping a provider variant with no compatible endpoint (there is no
  Anthropic-compatible Azure or xAI endpoint, so there is no `claude-azure`).
- Managing anyone's cloud accounts, billing or product credentials.
- Guessing an install command. Where a vendor documents no path for your OS,
  the kit says so and links the vendor.
- Being a company-specific tool: there is no built-in repository list, no
  internal host, no private endpoint anywhere in this repository.
