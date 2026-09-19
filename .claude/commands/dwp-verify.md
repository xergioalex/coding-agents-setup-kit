---
description: Read-only conformance check of a plan against this repo's plan convention
---

# /dwp-verify

Read [`docs/DEEP_WORK_PLANS.md`](../../docs/DEEP_WORK_PLANS.md) and check the
plan against it:

- every task has a stable id, a touched surface, acceptance criteria and a gate;
- every completed task carries real completion evidence;
- the plan ends with exactly one Final Review;
- nothing in the plan folder contains a secret or a private host.

Report pass/fail per item with the file and line. **Read-only.**
