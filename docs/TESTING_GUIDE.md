# Testing guide

## The gate

One command, no framework, no installs, no network:

```bash
tests/run.sh          # expect: passed: N  failed: 0
```

It runs inside a throwaway `HOME` under `tmp/`, so it never reads or writes your
real env file, `~/.codex`, `~/.pi`, `~/.ssh` or your shell rc, and it never
installs a CLI.

## Scoped runs

| Scope | Command | What it proves |
| --- | --- | --- |
| everything | `tests/run.sh` | all of the below |
| static checks | `tests/run.sh lint` | `bash -n` on every script, `py_compile` on every writer, `shellcheck -S warning` when installed, no key-shaped strings, no company-specific references, no stray markdown in `bin/`/`lib/`, and the doctor's wrapper list equals the contents of `bin/` |
| config writers | `tests/run.sh writers` | each writer creates, merges, preserves unrelated content, refuses invalid JSON without touching the file, keeps one backup, and never stores a raw value |
| Cursor resolver | `tests/run.sh resolver` | a Grok-branded `agent` is never reported as Cursor; `cursor-agent` wins; the versioned-directory fallback works; `cursorx` execs the real Cursor binary with `--force` |
| Herdr | `tests/run.sh herdr` | machine lookup by `target` against a **stubbed** herdr, including a hostile label/id/target that must never execute, and that every degradation path keeps the caller's exit code |
| machines | `tests/run.sh machines` | the machines file parses with its defaults, `ssh-config` renders only what is declared, an unknown name fails loudly, a bad config is refused, the Herdr half degrades, `ssh-config --write` refuses a file it did not generate, and lifecycle verbs refuse inside a container |
| onboarding | `tests/run.sh onboard` | onboarding prints no values, never writes `~/.ssh/config`, `install.sh` creates the env file once and never overwrites it, wrappers land on disk without markdown, PATH wiring is idempotent and preserves the rc |
| doctor | `tests/run.sh status` | keys reported by name and never by value, the OS is reported, a fresh machine is not called set up, an unknown verb exits non-zero, container refusal works, and every provider wrapper fails fast naming the missing CLI or variable |
| Windows layer | `tests/run.sh win` | every wrapper has a `.cmd` shim and vice versa, the dispatcher handles every wrapper name, `.cmd` files are CRLF+ASCII, shell scripts are LF, and — when `pwsh` is installed — every PowerShell file parses |

## Source → test mapping

| If you change… | Run at least |
| --- | --- |
| `bin/*` | `lint`, `status`, `win` (a new wrapper needs a shim) |
| `lib/common.sh` | `lint`, `resolver`, `status` |
| `lib/onboard.sh` | `lint`, `onboard`, `status` |
| `lib/herdr.sh` | `herdr` |
| `lib/agentbox.py` | `machines`, `herdr` |
| `lib/write_*.py` | `writers` |
| `install.sh` | `onboard`, `status` |
| `win/**`, `install.ps1` | `win` (and `pwsh` locally if you have it) |
| `docs/**` | `lint` (the secret and genericity greps read `docs/`) |

When in doubt, run the whole thing — it takes seconds.

## Blind spots (what the gate cannot cover)

The gate never launches a real CLI, never talks to a provider, never runs Docker
and never runs a real Herdr. These need a human:

```bash
agentkit status                   # what this machine actually has
claudex --help                    # the wrapper reaches the real CLI
codex-xai -c                      # provider variant: config written, session resumed
agentbox ls && agentbox status    # your machines file against real Docker
herdr --version && herdr status   # Herdr client/server
pwsh -NoProfile -File .\install.ps1 -Onboard   # the Windows path, on Windows
```

The PowerShell layer is **parsed** by the gate only when `pwsh` is installed on
the machine running it, and is never executed there. Anything about Windows in
these docs that you did not verify yourself should be treated as
`unverified on host` — and the pages say which parts those are.

## Adding a test

Tests live only in `tests/run.sh`, as `run_*` functions using
`check "<name>" <command>` or an explicit `if … pass/fail`. A new behavior gets
a check in the same commit. Prefer a stub over a real dependency: the suite must
stay runnable on a machine with none of these tools installed.
