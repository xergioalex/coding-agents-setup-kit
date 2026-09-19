# `.agents/` — the canonical agent harness for this repository

Personas, commands, skills and permissions for any AI coding agent working **on
this repo**. The content is plain Markdown, so Claude Code, Cursor, Codex,
Gemini, Copilot and Cline all read the same files.

```
.agents/
├── settings.json          permissions: what may run without asking, what must never run
├── agents/                personas: reviewer, executor, docs-writer, herdr-admin, …
├── commands/              thin delegators (/dwp-*, /skill-create, /agent-create) + /kit-onboard
├── skills/                the installed deepworkplan skill (gitignored — see below)
└── docs/                  the command reference and the persona catalog
```

| Invocation | Claude Code | Codex / Cursor / others | No slash commands |
| --- | --- | --- | --- |
| a command | `/dwp-create` | `#dwp-create` | "run dwp-create" |

## `.claude/` is a pointer, not a copy

The standard wants `.claude → .agents` as a symlink. **This host cannot create
symlinks** (Windows withholds `SeCreateSymbolicLinkPrivilege` without Developer
Mode, and this repo's `core.symlinks` is `false`), so `.claude/` holds one thin
pointer file per command and persona: frontmatter only, body pointing at the
canonical file here. Edit the file in `.agents/`; never the pointer.

That fallback is deliberate for a repository whose whole purpose is working
identically on macOS, Linux and Windows — a committed symlink would reach a
Windows clone as a text file containing a path.

## The skills directory is gitignored

`.agents/skills/` and `.claude/skills/` hold vendored third-party skill code.
This kit installs tools, it does not vendor them, so both are ignored.
`skills-lock.json` pins the source and hash; restore with:

```bash
npx --yes skills add DailybotHQ/deepworkplan-skill@v5.5.1 --skill deepworkplan --copy -y
```

The repository's rules for agents are in [`../AGENTS.md`](../AGENTS.md); this
folder only routes to them.
