# Contributing

The most valuable contribution to this repository is a **verified fact**: a flag
that changed, an installer URL that moved, a CLI that now works on an OS where it
did not. Those are exactly the things that rot.

## Before you open a pull request

```bash
tests/run.sh          # expect: passed: N  failed: 0
```

The gate runs in seconds, needs no dependencies, installs nothing and touches no
network.

## Ground rules

1. **Verify, do not assume.** Anything you add to a doc or a wrapper must come
   from `<cli> --help`, the vendor's official page, or a run you actually did —
   and you record the version and date next to it. Anything you could not verify
   gets the label `unverified on host`.
2. **No secrets, ever.** Not a real key, not a token, not a session id, not
   someone's SSH config or Herdr catalog. The lint scope greps for key-shaped
   strings and will fail you.
3. **Stay generic.** No employer, no internal host, no private repository, no
   machine list. `agentbox` reads a file the user writes. The lint scope checks
   this too.
4. **Respect what the user owns.** A writer merges only its own block, refuses
   what it cannot parse, and never stores a value. An installer never uninstalls,
   moves or re-links anything.
5. **Both sides or neither.** A new wrapper needs its `bin/` script, its
   `win/bin/*.cmd` shim, a branch in `win/lib/Invoke-Wrapper.ps1`, registration
   in `lib/onboard.sh` and `win/lib/Onboard.psm1`, a row in `bin/README.md` and
   `docs/coding-agents/wrappers-reference.md`, and a check in the gate.
6. **Conventional commits**: `type(scope): description`, scopes `bin`, `lib`,
   `win`, `install`, `tests`, `docs`, `herdr`, `meta`.

Full conventions: [`docs/STANDARDS.md`](docs/STANDARDS.md). What the gate covers
and what it cannot: [`docs/TESTING_GUIDE.md`](docs/TESTING_GUIDE.md).

## Especially wanted

- **Windows verification.** The Windows layer is static-checked and parsed, but
  nobody has executed it end to end. Run `.\install.ps1 -Onboard`, then
  `agentkit status`, and open an issue with what happened — including what broke.
- **Linux verification** of the vendor installers on distros other than
  Debian/Ubuntu.
- **New CLIs**, with their install path per OS, their full-permission flag and
  their session flags, each verified against a version you name.
- **New OpenAI-compatible providers** — the three writers already emit the right
  shape; see the recipe in [`docs/coding-agents/providers.md`](docs/coding-agents/providers.md).
- **Herdr corrections.** If `herdr --help` disagrees with a page in
  `docs/herdr/`, the binary is right and the page is a bug.

## Reporting a security problem

Open an issue describing the **class** of problem — never paste a value you
found. See [`docs/SECURITY.md`](docs/SECURITY.md).
