# Personas catalog

Subagent definitions in [`../agents/`](../agents/). They are plain Markdown with
a small frontmatter header: any agent runtime that supports personas can use
them, and a human can read them as a checklist.

| Persona | Role | Writes files? |
| --- | --- | --- |
| `reviewer` | Diff review: secrets, user-config safety, binary resolution, flag accuracy, doc drift, public-repo hygiene | no |
| `executor` | One bounded implementation, validated with `tests/run.sh` | yes |
| `docs-writer` | `docs/` and the module READMEs; sourced claims only | yes |
| `herdr-admin` | Herdr install, machines, containers, diagnosis — asks before anything that ends processes or edits user config | asks first |
| `host-onboarder` | Runs `AGENT_BOOTSTRAP.md` on this machine; reports by name, never by value | only via the installer, with consent |
| `security-auditor` | The security pass of a Final Review | no |
| `model-router` | Which tier / model / effort a task deserves, and the command that reaches it | no |

Two rules apply to all of them:

1. **Nothing under the developer's `$HOME` changes** without the human asking —
   `host-onboarder` is the one role whose whole job is that, and it still confirms
   before the first write.
2. **Nothing is claimed that was not verified.** Every persona reports what it
   ran, what it read, and what it could not check.

Adding a persona: one file in `../agents/`, a row in this table, and a reason it
cannot just be an instruction in `AGENTS.md`.
