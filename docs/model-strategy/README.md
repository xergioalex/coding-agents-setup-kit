# Model strategy

This kit puts seven coding agents and three extra providers one command away.
That makes the *choice* — which model, at which reasoning effort — the main lever
you have on cost, speed and quality. This folder is the operating guide for that
choice.

| Doc | What it is |
| --- | --- |
| [`TIERS.md`](TIERS.md) | The framework: three tiers, how to pick one, when to escalate and when to come back down, the orchestrator pattern, and the anti-patterns |
| [`KIT_MODEL_MAP.md`](KIT_MODEL_MAP.md) | The bridge to this kit: which wrapper and which env variable reach which tier, and the verified model / effort flag for each CLI |

The one rule, if you read nothing else:

> **Use the cheapest intelligence that reliably solves the task, and escalate
> deliberately when the problem earns it.** Plan with a strong model, execute
> with a fast one, review anything risky one tier up.

No model names or prices are hard-coded in this folder on purpose: they change
faster than documentation does. The tiers are defined by *behaviour* — what a
model is good for — so the guide stays true while you fill in today's names in
your env file.
