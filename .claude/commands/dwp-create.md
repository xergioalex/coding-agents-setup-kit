---
description: Turn a goal into an executable plan under .dwp/plans/ (this repo's plan convention)
---

# /dwp-create

Read [`docs/DEEP_WORK_PLANS.md`](../../docs/DEEP_WORK_PLANS.md) and follow the
**create** flow.

- Materialise a **Lite** plan at `.dwp/plans/PLAN_<name>/README.md`: goal, scope,
  and one task record per task with a stable id, touched surface, acceptance
  criteria and a validation gate.
- Promote to **Full** (one file per task) only when a compact record stops
  carrying a requirement or a gate.
- The plan itself is the artifact the human reviews. There is no separate draft.
- End the plan with the mandatory **Final Review** task.
- Do not start executing until the human says so, unless they already said
  `trust` or `auto`.

Ordinary direct requests ("fix this", "rename that") are done directly and never
become a plan.
