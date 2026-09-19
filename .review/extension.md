# Review overrides for this repository

Context for any automated or human diff review: this is a **host tooling kit**.
Bash and PowerShell wrappers that launch third-party coding agents with
permission prompts disabled, Python writers that merge provider config into
user-owned files, installers that edit PATH and run vendor installers, and
operational documentation for Herdr. There is no application runtime, no HTTP
surface and no database. Review for credential hygiene, user-config safety,
binary resolution, installer trust and documentation accuracy — not for
web-application findings.

## Always critical

- Any real key, token or session value in a tracked file, a test fixture or a doc.
- A writer that stores a secret **value** instead of an env reference
  (`env_key`, `{env:KEY}`, `$KEY`).
- A writer that can overwrite a user-owned file from `{}` on parse failure, drop
  other providers, or rewrite OpenCode's global `model`; any path that overwrites
  the user's env file.
- `cursorx` — or the detection behind it — able to launch or report the Grok
  `agent` binary as Cursor.
- An installer that uninstalls, moves or re-links an existing CLI, runs a global
  package-manager bootstrap, edits a shell rc beyond the one guarded PATH block,
  touches Windows' machine-wide `Path`, or points `curl | bash` anywhere but the
  vendor's documented URL.
- A company name, a real host, a private repository URL or a personal machine
  list: this repository is public.

## Escalate to warning

- A new wrapper missing from `AGENTKIT_WRAPPERS` (`lib/onboard.sh`),
  `$script:Wrappers` (`win/lib/Onboard.psm1`), `bin/README.md`,
  `docs/coding-agents/wrappers-reference.md`, or the Windows side entirely.
- A flag added without a "verified against `<version>`" note, or a Herdr claim
  not traceable to `herdr --help` or a linked official page.
- Markdown placed in `bin/` or `lib/` other than `README.md` (the installer
  strips it from the PATH directory, and `bin/*` globs would try to run it).
- A behaviour change with no matching check in `tests/run.sh`.
- A `.cmd` file that is not CRLF, or a shell script that is.

## Deliberately not findings

- The full-permission flags themselves (`--dangerously-skip-permissions`,
  `--yolo`, `--force`, `--auto`, `--approve`) — they are the purpose of the kit
  and are documented as such in `docs/SECURITY.md`.
- Cline receiving its key on argv: a documented upstream limitation with
  documented mitigations. Flag it only if an env-reference mechanism now exists.
- `curl | bash` against a vendor's own documented URL, with `docs/SECURITY.md`'s
  posture stated.
