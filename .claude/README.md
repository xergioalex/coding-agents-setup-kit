# `.claude/` — the agent harness for this repository

Slash commands, personas and permissions for AI coding agents working **on this
repo**. Claude Code reads this path natively; other agents can read the same
files — the content is plain Markdown and applies to any of them.

```
.claude/
├── settings.json          permissions: what may run without asking, what must never run
├── commands/              thin delegators (/dwp-*, /kit-onboard)
├── agents/                personas: reviewer, executor, docs-writer, herdr-admin, …
└── docs/                  the command reference and the persona catalog
```

| Invocation | Claude Code | Codex / Cursor / others |
| --- | --- | --- |
| a command | `/dwp-create` | `#dwp-create`, or just "run dwp-create" |

Each command file says what to read and what to do; none of them contains the
procedure twice. The plan convention itself lives in
[`../docs/DEEP_WORK_PLANS.md`](../docs/DEEP_WORK_PLANS.md).

The repository's rules for agents are in [`../AGENTS.md`](../AGENTS.md); this
folder only routes to them.
