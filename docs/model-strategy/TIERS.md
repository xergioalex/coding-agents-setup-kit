# Tiers, escalation, and how to spend intelligence

## Three tiers

| Tier | What it is | Give it |
| --- | --- | --- |
| **Daily** | The fast, cheap, coding-tuned model of each provider. Low latency, high throughput. | Mechanical edits, renames, boilerplate, tests for code that already exists, docs, small well-specified features, exploration and search |
| **Reasoning** | The provider's strong general model at normal or high effort. | Debugging something you do not understand, design and architecture decisions, multi-file refactors, reviewing risky changes, anything where being wrong is expensive |
| **Super Reasoning** | The frontier model at maximum effort, or a second model used as a cross-check. | Problems the Reasoning tier already failed at, decisions that are hard to reverse, subtle correctness or security questions |

Each provider has all three; the names change every few months. Put today's
choices in your env file (`*_MODEL_DAILY`, `*_MODEL_REASONING`) and move on.

## Choosing, in one question

> **Do I know what the answer looks like?**

Yes, and it is mostly typing → **Daily**.
No, or the shape of the solution is the actual question → **Reasoning**.
No, and the last attempt was already a Reasoning model → **Super Reasoning**.

Two things that should push you *up* a tier regardless of the task's size:

- **Blast radius.** A three-line change to an auth check deserves more thinking
  than a three-hundred-line change to a test fixture.
- **Reversibility.** A migration, a schema change, a public API, anything you
  cannot quietly revert.

And two that should push you *down*:

- **A precise spec.** If you can write the acceptance criteria in three bullets,
  a Daily model will usually hit them.
- **A tight feedback loop.** With a fast test suite, a cheap model that tries
  twice often beats an expensive one that tries once.

## Escalate on evidence, not on nerves

Escalate when you have a **concrete failure**: the change did not work, the
explanation did not match the code, the model contradicted itself, or two
attempts produced the same wrong answer. "This feels hard" is not evidence —
try the cheap tier first; you will be right most of the time and it costs seconds.

When you escalate, bring the evidence with you: the failing output, what was
already tried, and what you ruled out. A strong model with no context is just an
expensive weak model.

## De-escalate as soon as the hard part is over

The expensive part of a task is usually a small fraction of it. Once the
Reasoning tier has decided *what* to do, hand the typing back to a Daily model:

```
Reasoning  →  "here is the plan, the files and the risks"
Daily      →  implements it, runs the tests, fixes the obvious breakage
Reasoning  →  reviews the diff if the blast radius earns it
```

## The orchestrator pattern (this is where Herdr pays off)

One reasoning coordinator, several cheap workers, a reviewer one tier up — each
in its own pane, all visible at once:

```
Herdr workspace
├── pane 1   claudex --model <reasoning>            coordinator / planner
├── pane 2   cursorx                                coding executor
├── pane 3   codexx -c model_reasoning_effort=low   tests, docs, mechanical work
├── pane 4   grokx -m <daily>                       exploration and research
└── pane 5   claudex --model <reasoning>            reviewer (ideally a different provider)
```

Drive it from a script with `herdr agent start … -- <cli flags>` and
`herdr agent prompt` — everything after `--` goes straight to the CLI, so the
model and effort flags in [`KIT_MODEL_MAP.md`](KIT_MODEL_MAP.md) work there too.
See [`../herdr/06-agent-automation.md`](../herdr/06-agent-automation.md).

Reviewing with a **different provider** than the one that wrote the code is
worth more than reviewing with a bigger model from the same family: different
training, different blind spots.

## Anti-patterns

| Anti-pattern | Why it hurts |
| --- | --- |
| Frontier model for everything | You pay latency on every keystroke-level task and stop noticing when thinking was actually needed |
| Cheapest model for everything | You pay in debugging, in retries, and in wrong decisions that ship |
| Escalating without new context | The stronger model repeats the same mistake with more confidence |
| Never de-escalating | The whole task runs at the cost of its hardest minute |
| Maximum effort by default | Reasoning effort is a dial, not a quality setting; on mechanical work it mostly adds delay |
| Judging a model by one bad run | Two runs and a written note beat a strong opinion |

## Keep it honest

Write down what actually happened: which wrapper, which model, which effort,
how many retries, how many minutes of your own time. A week of those notes tells
you more about which tier to use than any benchmark, because it is measured on
*your* codebase.
