# `tests/`

One file, one command, no framework:

```bash
tests/run.sh                 # everything — expect "passed: N  failed: 0"
tests/run.sh lint            # or a single scope
```

Scopes: `lint`, `writers`, `resolver`, `herdr`, `machines`, `onboard`, `status`,
`win`.

Everything runs inside a throwaway `HOME` under `tmp/`, created with `mktemp` and
removed on exit. The suite never reads or writes your real config, never installs
a CLI, and never touches the network — a stub `herdr`, fake `agent` and
`cursor-agent` binaries, and a fake machines file stand in for the real things.

What it covers, what it cannot cover, and how to add a check:
[`../docs/TESTING_GUIDE.md`](../docs/TESTING_GUIDE.md).

Conventions:

- Tests are `run_<scope>` functions using `check "<name>" <command>` or an
  explicit `if … pass/fail` when the assertion needs more than an exit code.
- A test name reads as the property being asserted
  ("status never prints secret values"), not as the mechanism.
- Prefer a stub over a real dependency, always.
