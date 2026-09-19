# AI agent onboarding — working *on* this repository

You are changing the kit itself. (To *install* it on a machine, use
[`../AGENT_BOOTSTRAP.md`](../AGENT_BOOTSTRAP.md) instead — different job,
different rules.)

## First session, in order

1. Read [`../AGENTS.md`](../AGENTS.md) — the whole thing, it is short.
2. Read [`STANDARDS.md`](STANDARDS.md) and [`SECURITY.md`](SECURITY.md). The
   hard rules there are not stylistic preferences; several of them exist because
   the alternative leaked a key or destroyed someone's config.
3. Run the gate before touching anything, so you know the baseline is green:
   ```bash
   tests/run.sh
   ```
4. Read the module README of the folder you are about to change:
   [`../bin/README.md`](../bin/README.md), [`../lib/README.md`](../lib/README.md),
   [`../tests/README.md`](../tests/README.md).

## While you work

- Keep the session-flag contract (`-c`, `-r [id]`, `-l`) on **both** sides: a
  wrapper in `bin/` and its branch in `win/lib/Invoke-Wrapper.ps1` plus a
  `.cmd` shim. The gate checks they exist; only you can check they agree.
- A new wrapper must also be registered in `lib/onboard.sh` (`AGENTKIT_WRAPPERS`)
  and `win/lib/Onboard.psm1`, and appear in `bin/README.md` and
  `docs/coding-agents/wrappers-reference.md`.
- Wrappers `exec` the CLI as their last statement. Writers stay merge-safe and
  secret-free. Guards fail with the **name** of what is missing.
- Every new behaviour gets a check in `tests/run.sh`, in the same change.
- Never add a flag to a doc without the version you verified it against, or the
  label `unverified on host`.

## Never, without being asked

- Install anything on the developer's machine, or run `install.sh` / `install.ps1`
  / `agentkit onboard` outside the test sandbox.
- Read or print their env file, `~/.grok/auth.json`, `~/.codex/auth.json`, their
  SSH config or their Herdr catalog.
- Invent a CLI flag, an install URL or a package name.
- Add a company name, a real host, a private repository or a machine list to this
  repository. It is public, and `tests/run.sh lint` will fail you.
- Commit or push.

## Before you say you are done

```bash
tests/run.sh          # expect: passed: N  failed: 0
```

Then report: what changed, what you verified and how, what remains unverified
(for example "the Windows path was not executed — no Windows machine here"), and
anything you decided that a human might want to decide differently.
