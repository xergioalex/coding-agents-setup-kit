# `agentbox` — the machines you run agents on

The wrappers cover *which agent* you run. `agentbox` covers *where*: a
docker-compose dev container, a VM, a remote box you only reach over SSH. It
starts and stops them, opens a shell on them, generates their SSH config block,
and keeps each one's **Herdr saved machine** in step.

Everything it knows comes from a file you write. This kit ships no machine list.

## The machines file

Default location: `~/.config/coding-agents-kit/machines.toml`
(`%APPDATA%\coding-agents-kit\machines.toml` on Windows), overridable with
`AGENTKIT_MACHINES`. Start from [`machines.example.toml`](../machines.example.toml):

```toml
[[machine]]
name    = "devbox"                              # what you type: agentbox up devbox
ssh     = "devbox"                              # SSH alias — also the Herdr join key
label   = "Dev box"                             # label used when creating the Herdr machine
compose = "~/src/devbox/docker-compose.yml"     # omit for an SSH-only machine
service = "devbox"                              # omit to act on the whole compose file
host    = "127.0.0.1"                           # only for `agentbox ssh-config`
port    = 22029
user    = "dev"
```

Only `name` is required. `ssh` and `label` default to `name`. The parser accepts
exactly this subset — `[[machine]]` tables with scalar values — and refuses
anything else with a line number rather than half-understanding it.

## Verbs

| Command | What it does |
| --- | --- |
| `agentbox ls [--json]` | every declared machine with its container state |
| `agentbox status [name]` | compose state, whether the SSH alias resolves and answers, and the Herdr machine state |
| `agentbox up\|stop\|down\|restart <name>` | delegates to that machine's own compose file, then moves its Herdr machine |
| `agentbox ssh <name> [-- cmd…]` | `ssh <alias>`, optionally running a command |
| `agentbox herdr [name] [status\|add\|enable\|disable\|remove]` | act on the Herdr machine itself |
| `agentbox ssh-config [--write]` | render (or write) the kit-owned SSH include |
| `agentbox doctor` | reconcile the three sources that must agree |

`--no-herdr` (or `AGENTBOX_NO_HERDR=1`) turns the Herdr half off entirely.

## The Herdr lifecycle, and why it works that way

`up` **enables** that machine; `stop` and `down` **disable** it. Either of the
latter leaves the box unable to answer SSH, so an enabled machine would only be
a sidebar entry that fails to connect and retries forever.

The machine is found by matching its Herdr `target` against your SSH alias — so
there is no machine id to configure anywhere, and nothing breaks when one
changes. An **existing machine is never modified**: Herdr can rename a label but
not a target, so a mismatch is fixed by removing and re-adding it, which is your
decision, not a command's.

`agentbox herdr <name> add` creates one, and it is deliberately loud: it refuses
unless the SSH alias resolves and you are in a terminal, because
`herdr machine add` prompts.

**Herdr never fails your containers.** If it is not installed, if there is no
machine yet, or if a call errors, you get one warning and the exit code of the
Docker work you asked for.

## SSH config generation

```bash
agentbox ssh-config            # print the blocks
agentbox ssh-config --write    # write ~/.ssh/config.d/coding-agents-kit
```

The generated file carries a provenance header, is written atomically with
restrictive permissions, and contains no secrets. Your own `~/.ssh/config` is
**never written** — the one line you add yourself is printed for you:

```sshconfig
Include ~/.ssh/config.d/coding-agents-kit
```

Put it near the top of the file: OpenSSH takes the first value it finds for each
keyword. Use `127.0.0.1` rather than `localhost` for containers on your own
machine — `localhost` can resolve to IPv6 `::1` and reach a different listener.

## Doctor

```bash
agentbox doctor
```

Reconciles three things that must agree for the sidebar and `agentbox ssh` to
work: your machines file, your SSH config, and the Herdr catalog. It reports and
never fixes what you own. The failure it exists to catch is silent: the
containers come up, SSH works, and the sidebar entry simply stays grey because
the machine's `target` and your alias are spelled differently.

## Host only

The lifecycle verbs refuse to run inside a container: Docker, your SSH config
and Herdr all live on the host, and a container cannot reach them. Read-only
verbs (`ls`, `status`, `doctor`, `ssh-config`) run anywhere.
