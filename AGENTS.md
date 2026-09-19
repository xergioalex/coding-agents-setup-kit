# AGENTS.md — coding-agents-setup-kit

Compact entry point for any AI coding agent (Claude Code, Cursor, Codex, Gemini,
Copilot, Cline, …) working **on this repository**. To *install* the kit on a
machine instead, use [`AGENT_BOOTSTRAP.md`](AGENT_BOOTSTRAP.md) — different job,
different rules.

DWP standard: 5.0.0 (onboarded 2026-09-18; skill 5.5.1)

## What this repo is

A cross-platform kit that installs the terminal coding agents (Claude Code,
Codex, Cursor Agent, OpenCode, Pi, Cline, Grok), wraps them in one uniform
full-permission command surface with provider variants for Z.AI GLM, xAI and
Azure OpenAI, and documents how to run them inside Herdr. Bash + PowerShell +
stdlib Python. No runtime service, no build step, no package manager.

**It is public and generic.** No employer, no internal host, no private
repository, no machine list — `agentbox` reads a file the user writes. The lint
gate enforces this.

## Repository structure

```
.
├── install.sh / install.ps1    idempotent installers (--onboard / -Onboard fill gaps)
├── bin/                        23 wrappers + agentkit (doctor) + agentbox (machines)  → bin/README.md
├── win/                        bin/*.cmd shims + lib/ PowerShell (one dispatcher)     → docs/WINDOWS.md
├── lib/                        common.sh, host.sh, herdr.sh, onboard.sh, agentbox.py,
│                               write_*.py (config writers)                            → lib/README.md
├── env.example                 variable names only
├── machines.example.toml       optional machine list template
├── tests/run.sh                the gate (sandbox HOME, no installs, no network)       → tests/README.md
├── docs/                       canonical guides + coding-agents/ + herdr/ + model-strategy/
├── .agents/                    canonical agent harness: agents/, commands/, skills/,
│                               docs/ (catalog + command reference), settings.json
└── .claude/                    thin pointers into .agents/ (this host cannot symlink)
```

## Documentation index

| Doc | What it owns |
| --- | --- |
| [`docs/PRODUCT_SPEC.md`](docs/PRODUCT_SPEC.md) | What the kit is for, in non-technical terms |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | The wrapper -> lib -> CLI layering, where state lives, key decisions |
| [`docs/STANDARDS.md`](docs/STANDARDS.md) | Coding conventions for bash, PowerShell and the Python writers |
| [`docs/TESTING_GUIDE.md`](docs/TESTING_GUIDE.md) | The gate, its scopes, the source-to-test mapping, blind spots |
| [`docs/DEVELOPMENT_COMMANDS.md`](docs/DEVELOPMENT_COMMANDS.md) | Every command verbatim, including sandboxed installer runs |
| [`docs/SECURITY.md`](docs/SECURITY.md) | Secret handling, the Cline argv exception, config-write safety |
| [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md) | Wrapper startup cost and the per-launch config write |
| [`docs/WINDOWS.md`](docs/WINDOWS.md) | The `.cmd` + PowerShell layer and why it has no `exec` |
| [`docs/machines.md`](docs/machines.md) | The machines file `agentbox` reads |
| [`docs/DEEP_WORK_PLANS.md`](docs/DEEP_WORK_PLANS.md) | This repo's plan convention |
| [`docs/AI_AGENT_ONBOARDING.md`](docs/AI_AGENT_ONBOARDING.md) . [`docs/AI_AGENT_COLLAB.md`](docs/AI_AGENT_COLLAB.md) | How an agent gets productive here and how agents hand off |
| [`docs/coding-agents/`](docs/coding-agents/README.md) | One page per CLI + the provider matrix + wrapper reference |
| [`docs/herdr/`](docs/herdr/README.md) . [`docs/model-strategy/`](docs/model-strategy/README.md) | Herdr operation . tier/model routing |

## Quick commands

| Action | Command | Notes |
| --- | --- | --- |
| Validate everything (**full**) | `tests/run.sh` | ~seconds · expect `failed: 0` |
| Validate one area (**scoped**) | `tests/run.sh lint\|writers\|resolver\|herdr\|machines\|onboard\|status\|win` | see `docs/TESTING_GUIDE.md` |
| Lint only | `shellcheck -S warning install.sh lib/*.sh bin/* tests/run.sh` | needs shellcheck |
| Doctor (read-only) | `bash bin/agentkit status` | reads PATH and config; writes nothing |
| Try a wrapper | `bash bin/claudex --help` | works straight from the checkout |
| Install on this machine | `./install.sh --onboard` | **writes to `$HOME`** — a human decision |

## Mandatory rules

1. **English only** in scripts, comments, docs and commits.
2. **Conventional commits**: `type(scope): description`; scopes `bin`, `lib`,
   `win`, `install`, `tests`, `docs`, `herdr`, `meta`.
3. **Validation rule.** Pick scopes from what you touched using the mapping in
   [`docs/TESTING_GUIDE.md`](docs/TESTING_GUIDE.md); when unsure run the whole
   gate. Tests live only in `tests/run.sh`; new behaviour gets a check.
4. **Secrets.** Never print, log or write a value of `*_API_KEY` / `*_TOKEN`.
   Writers reference the environment (`env_key`, `{env:KEY}`, `$KEY`). The user's
   env file is never overwritten and never transcribed. Cline's argv key is the
   one documented exception. See [`docs/SECURITY.md`](docs/SECURITY.md).
5. **User config is sacred.** Writers merge only the block they own, refuse
   unparsable input (never `{}`), write atomically, keep one `.bak`. Never set
   OpenCode's global `model`. Never edit a shell rc beyond the one guarded PATH
   block, and never touch Windows' machine-wide `Path`.
6. **Cursor is resolved, not assumed.** `command -v agent` may be Grok. Use
   `agentkit_cursor_bin` / `Resolve-CursorBin`.
7. **Do not invent CLI flags, package names or install URLs.** Verify against
   `<cli> --help` or the vendor's page and record the version in
   `docs/coding-agents/<cli>.md`. Unverified claims carry the label
   `unverified on host`.
8. **Both sides or neither.** A new wrapper needs `bin/<name>`,
   `win/bin/<name>.cmd`, a branch in `win/lib/Invoke-Wrapper.ps1`, registration
   in `lib/onboard.sh` **and** `win/lib/Onboard.psm1`, rows in `bin/README.md`
   and `docs/coding-agents/wrappers-reference.md`, and a check in the gate.
9. **Stay generic and public-safe.** No company name, no real host, no private
   URL, no personal machine. No markdown in `bin/` or `lib/` except `README.md`.
10. **Developing ≠ installing.** Working on the kit must not install or modify
    anything under the developer's `$HOME`. `install.sh`, `install.ps1` and
    `agentkit onboard` run only when the human asks. Commit and push only when
    asked.
11. **Errors** are one-line `agentkit: …` / `agentbox: …` messages on stderr that
    name the fix; Unix wrappers `exec` the CLI last.
12. **Herdr is documented, not wrapped.** `herdr --help` is the authority on
    syntax; a page here that disagrees with it is a bug.

## Structured work

Long or multi-session work runs as a **Deep Work Plan**. The flows live in the
installed `deepworkplan` skill (`.agents/skills/deepworkplan/`, v5.5.1); the
delegators in [`.agents/commands/`](.agents/commands/) are thin aliases that
route to it, and never restate the flow:

| Intent | Command | Sub-skill |
| --- | --- | --- |
| turn a goal into a plan | `/dwp-create` | `create` |
| run it task by task | `/dwp-execute` | `execute` |
| add, remove or reorder tasks | `/dwp-refine` | `refine` |
| continue an interrupted plan | `/dwp-resume` | `resume` |
| progress, read-only | `/dwp-status` | `status` |
| conformance, read-only | `/dwp-verify` | `verify` |
| check for a newer skill | `/dwp-upgrade` | `upgrade` |
| evolve this repo's own kit | `/skill-create`, `/agent-create` | `author` |

This repo's own plan conventions — the scopes a gate may select, the mandatory
**Final Review** (security pass, full gate on the final tree, documentation
reconciliation) — stay in
[`docs/DEEP_WORK_PLANS.md`](docs/DEEP_WORK_PLANS.md); read it alongside the flow.
Plans land in the gitignored `.dwp/plans/`; scratch goes in `tmp/`. Ordinary
direct requests are done directly and never silently become a plan.

Other agents: the sub-skills are user-invocable directly
(`#deepworkplan-create`, or plain "run deepworkplan-create" on hosts without
slash commands).

## Working principles

Work with autonomy and sound judgment inside the current request; these defaults
never override the rules above, the human's permissions, or a read-only flow.

- **Own the outcome.** Carry authorised work through investigation, change and
  validation until it is done or a concrete blocker stops it.
- **Be resourceful before asking.** `<cli> --help`, the vendor pages linked in
  `docs/`, and the gate answer most questions.
- **Make routine decisions independently**; state consequential assumptions.
- **Ask when authorisation is missing** — anything touching the developer's
  `$HOME`, SSH config, Herdr catalog, or publishing — with the investigation and
  a recommendation attached.
- **Make approvals concrete:** prepare the change, run the gate, then ask.
- **Respect intent and scope.** An audit stays an audit.
- **Communicate directly:** result first; say plainly what is verified, what is
  assumed, and what nobody has checked.
- **Verify before declaring completion:** `tests/run.sh` green, docs updated for
  what changed, and an honest list of what remains unverified.
