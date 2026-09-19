# Working together — humans, and several agents

## Who owns what

| Surface | Owner | Notes |
| --- | --- | --- |
| `bin/`, `lib/`, `win/`, `tests/` | anyone, behind the gate | a change without a green `tests/run.sh` is not a change |
| `docs/` | anyone, with sources | a claim needs a version or a link |
| The developer's machine | **the human** | installing, PATH, `~/.ssh`, Herdr machines, integrations |
| The env file | **the human, always** | the kit creates it once from names; nobody else reads or writes it |
| Publishing: commits, tags, releases | **the human** | agents prepare, humans push |

## Handoff between sessions or agents

Leave the next one what you would want:

- **What changed**, as files and behaviour, not as narrative.
- **What was verified**, with the command and its real output.
- **What was not**, explicitly — "the Windows layer was never executed" is
  useful; silence is not.
- **What you decided and why**, especially where you chose between two
  reasonable options.

When a plan is involved, that belongs in the plan
([`DEEP_WORK_PLANS.md`](DEEP_WORK_PLANS.md)); otherwise it belongs in the
message that ends your turn.

## Avoiding collisions

- One agent per surface at a time. Two agents editing `lib/onboard.sh` will
  produce a merge no gate can save.
- `tests/run.sh` uses a sandbox under `tmp/` and cleans up after itself, so it is
  safe to run concurrently.
- If you must work in parallel, split by folder (`bin/` vs `docs/` vs `win/`) and
  agree on who owns the shared registries (`lib/onboard.sh`,
  `win/lib/Onboard.psm1`, `bin/README.md`).

## What only a human decides

- Running any installer against a real home directory.
- Adding, removing or renaming a Herdr machine on their catalog.
- Installing a Herdr integration (it edits the agent's own config).
- Adding a provider, because it implies a key they must obtain and store.
- Making this repository's history public, and anything that touches it:
  commits, force-pushes, tags, releases.
