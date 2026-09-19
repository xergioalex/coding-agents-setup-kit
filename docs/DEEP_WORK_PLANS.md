# Deep work plans

Structured, resumable work for AI agents in this repository. A plan is a folder
that outlives a single session, so an interrupted piece of work can be picked up
by another agent — or by you tomorrow — without re-deriving the context.

Plans are **gitignored**: they live in `.dwp/plans/PLAN_<name>/` and are working
state, not deliverables.

## When to use one

| Situation | What to do |
| --- | --- |
| "fix this typo", "rename that", a bounded edit | do it directly — never silently turn a small request into a plan |
| work spanning several files with a validation gate at the end | a **Lite** plan |
| long-horizon work, many tasks, several sessions, or handoffs between agents | a **Full** plan |

Ordinary direct requests stay direct. A plan is something the human asked for
("plan this", "create a plan"), or something you proposed and they accepted.

## Shape of a plan

```
.dwp/plans/PLAN_<name>/
├── README.md              the plan: goal, scope, task list, status of each task
├── analysis_results/      evidence produced while executing (reports, findings)
└── tasks/                 Full plans only: one file per task
```

Each task record — inline in `README.md` for a Lite plan, one file per task for a
Full plan — carries the same five things:

1. **A stable id** (`T1`, `T2`, …) that never gets renumbered.
2. **Touched surface**: which files and commands this task is allowed to change.
3. **Acceptance criteria**: what "done" means, in terms someone else can check.
4. **Validation gate**: the exact command that proves it (for this repo, usually
   `tests/run.sh` or a scoped run of it).
5. **Completion evidence**: what was actually run and what it printed.

## The loop

| Intent | What it means here |
| --- | --- |
| create | turn the goal into an executable plan; the plan itself is the artifact you review |
| execute | run it task by task, validating each gate before moving on |
| refine | add, remove or reorder tasks; promote a Lite plan to Full when a compact record stops carrying a requirement |
| resume | continue an interrupted plan from its recorded state |
| status | read-only progress report |
| verify | read-only conformance check against this document |

An agent host with slash commands can expose these as `/dwp-create`,
`/dwp-execute`, `/dwp-refine`, `/dwp-resume`, `/dwp-status`, `/dwp-verify` —
this repository ships those as thin delegators in `.claude/commands/`. Hosts
without slash commands do the same thing by name.

## Every plan ends with one Final Review

A single mandatory closing task that covers three things:

1. **Security pass** — against [`SECURITY.md`](SECURITY.md): no secret written or
   printed, no user-owned config overwritten, no wrong binary launched, no
   company-specific or private data added to a public repository. A critical
   finding **blocks** completion.
2. **Final-state validation** — the full gate on the final tree, not on the state
   after the last task: `tests/run.sh` with `failed: 0`.
3. **Documentation reconciliation** — every flag that changed carries the version
   it was verified against, every new wrapper appears in `bin/README.md`,
   `docs/coding-agents/wrappers-reference.md` and the doctor's wrapper list, and
   anything unverified is labelled `unverified on host`.

## Rules for the agent running a plan

- Do not start a plan for work that was not asked to be planned.
- Never mark a task complete without its gate's real output.
- Never invent evidence, a version number or a flag.
- Stop and ask when the plan requires a decision the human owns: installing
  something on their machine, touching `~/.ssh`, publishing, pushing.
- `trust` / `auto` from the human authorises unattended continuation **within**
  the flow they asked for; it never selects the flow for them, and read-only
  flows stay read-only.
