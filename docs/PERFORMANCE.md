# Performance

A wrapper adds three things to a launch: sourcing `lib/common.sh` and reading
the env file, a couple of guard checks, and — for provider variants only — one
`python3` run that writes or merges the provider config. On a normal machine
that is a few tens of milliseconds, against a CLI that then takes a second or
more to start its own runtime.

**Why the writers run on every launch instead of once at install time:** the
model, the endpoint and the deployment names come from your env file. If the
config were written once, editing that file would silently do nothing until you
re-ran the installer — and the two sources of truth would drift. Regenerating is
cheap, and it means there is exactly one place to change anything.

**Why `exec`:** the wrapper replaces its own process with the CLI, so there is no
extra process alive during the session, signals (Ctrl+C) reach the CLI directly,
and the exit code is the CLI's own. On Windows, where PowerShell has no `exec`,
the shim stays as a parent — which costs one process and matters for how Herdr
detects the agent. See [`WINDOWS.md`](WINDOWS.md).

If a launch feels slow, measure before blaming the wrapper:

```bash
time bash bin/claudex --help      # the wrapper path
time claude --help                # the CLI alone
```
