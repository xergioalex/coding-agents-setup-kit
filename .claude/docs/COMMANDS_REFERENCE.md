# Commands reference

Slash commands available in this repository. Claude Code invokes them with `/`;
Codex, Cursor and most other CLIs intercept `/` for their own menus, so they use
`#` — or you can simply say the name in plain text ("run dwp-status").

| Command | Procedure | Writes? |
| --- | --- | --- |
| `/dwp-create` | [`commands/dwp-create.md`](../commands/dwp-create.md) | creates a plan under `.dwp/` (gitignored) |
| `/dwp-execute` | [`commands/dwp-execute.md`](../commands/dwp-execute.md) | yes — that is the point |
| `/dwp-refine` | [`commands/dwp-refine.md`](../commands/dwp-refine.md) | the plan only |
| `/dwp-resume` | [`commands/dwp-resume.md`](../commands/dwp-resume.md) | yes |
| `/dwp-status` | [`commands/dwp-status.md`](../commands/dwp-status.md) | **read-only** |
| `/dwp-verify` | [`commands/dwp-verify.md`](../commands/dwp-verify.md) | **read-only** |
| `/kit-onboard` | [`commands/kit-onboard.md`](../commands/kit-onboard.md) | **writes to `$HOME`** — ask the human first |

When a command is invoked, the agent must **read the linked procedure file
completely and follow it** — the file is the specification, not a summary of one.
Read-only commands stay read-only however they were invoked. A `trust` or `auto`
from the human authorises unattended continuation **within** the flow they asked
for; it never picks the flow.

The plan convention these commands implement is
[`../../docs/DEEP_WORK_PLANS.md`](../../docs/DEEP_WORK_PLANS.md).
