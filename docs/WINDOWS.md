# Windows

The kit gives Windows the same command surface as macOS and Linux. Two paths
exist and they are meant to be mixed deliberately, not by accident.

| Path | What it is | Install with |
| --- | --- | --- |
| **Native** | `.cmd` shims on your user PATH that call PowerShell, which launches the CLI installed on Windows | `.\install.ps1 -Onboard` |
| **WSL2** | The Unix kit installed inside your distro; the CLIs and their config live there | `./install.sh --onboard` **inside** the WSL shell |

A WSL shell is not a container: it has its own home directory, its own PATH and
its own config. The kit installs into it normally. What it must not do is claim
to report the Windows side's state — they are two machines that share a disk.

> **Verification status.** The bash side of this kit is exercised by
> `tests/run.sh` on macOS and Linux, and the gate also runs green under Git Bash
> on Windows. The Windows layer is checked **statically** (every wrapper has a
> shim, the dispatcher handles every name, encodings are right) and is parsed by
> `pwsh` and/or Windows PowerShell 5.1 when either is on the machine running the
> gate.
>
> **Executed on Windows 11 with Windows PowerShell 5.1 (2026-10-03):**
> `.\install.ps1 -Onboard` end to end; `agentkit status`; every CLI wrapper
> reaching its real CLI (`claudex`, `codexx`, `cursorx`, `opencodex`, `pix`,
> `clinex`, `grokx` with `--version`); and every provider wrapper refusing with
> its one-line `agentkit:` message when its key is unset; `agentkit
> path|env-path|<unknown verb>` and `agentbox --help|ls`. A provider wrapper
> **with** a key (config writer + real session) was not exercised there; treat
> that part as `unverified on host`.

## Your keys on Windows

The env file lives at `%APPDATA%\coding-agents-kit\env` (`agentkit env-path`
prints it). The installer creates it from `env.example` with every line
commented out, locks its ACL to your user, and never overwrites it again.

```powershell
notepad (agentkit env-path)
```

Uncomment and fill only what you use — one `NAME=value` per line (quotes optional,
no comment after the value: it would become part of it). Every wrapper reads the
file into **its own process** at launch, so a change takes effect on the next
launch; no new terminal is needed.
Which variable each wrapper needs is in [`../INSTALL.md`](../INSTALL.md#your-keys);
endpoints and model variables are in
[`coding-agents/providers.md`](coding-agents/providers.md).

## How a Windows wrapper works

```
claudex  ->  %LOCALAPPDATA%\coding-agents-kit\bin\claudex.cmd
               -> pwsh (or powershell) -NoProfile -ExecutionPolicy Bypass
                    -File ..\lib\Invoke-Wrapper.ps1 claudex <your args>
                      -> Import-AgentKitEnv          (reads %APPDATA%\coding-agents-kit\env)
                      -> Assert-Command / Assert-EnvVar
                      -> [provider variants] python .\lib\write_*.py …
                      -> & claude --dangerously-skip-permissions <your args>
                      -> exit $LASTEXITCODE
```

**Git Bash** (and other MSYS2/Cygwin shells) cannot run `claudex.cmd` by its
bare name, so the installer also writes an extensionless bash shim per wrapper
into the same `bin` directory, rendered from `win/lib/bash-shim.sh`. It calls the
same PowerShell entry point with the same env file, so `claudex`, `claude-glm`,
`agentkit` … behave identically in PowerShell, `cmd.exe` and Git Bash.
PowerShell and `cmd.exe` keep resolving the `.cmd` first. Open a **new** Git
Bash after installing: it builds its `PATH` from the Windows user `Path` at
startup. Verified non-interactively (`--version`, missing-key refusal) on
2026-10-03; a full interactive TUI session through the shim inside mintty is
`unverified on host` — if one misbehaves, launch it from Windows Terminal or
PowerShell instead.

`Invoke-Wrapper.ps1` holds **every** wrapper's mapping in one file, so the
Windows and Unix sides cannot drift apart; the gate asserts that each name
exists on both.

## Things that bite on Windows, and what the kit does

| Hazard | Why it bites | What the kit does |
| --- | --- | --- |
| Execution Policy | `.ps1` files are blocked by default | the `.cmd` shim passes `-ExecutionPolicy Bypass` for **that script only**; the machine policy is never changed |
| `pwsh` vs `powershell` | PowerShell 7 is not installed everywhere | each shim uses `pwsh` when present and falls back to Windows PowerShell |
| Mark-of-the-Web / SmartScreen | a downloaded CLI binary fails in ways that look like a bug | `Test-MarkOfTheWeb` warns and prints the `Unblock-File` command (this is the Windows analogue of a broken code signature on macOS) |
| The `agent` name collision | Cursor and the Grok CLI both install `agent` | `Resolve-CursorBin` prefers `cursor-agent`, rejects Grok by path and by version banner, then looks in Cursor's own versioned directory |
| User `Path` length and `%VAR%` expansion | a careless rewrite truncates or flattens your PATH | read-modify-write of the **user** `Path` only, skipped when the entry is already there, previous value saved to `path-backup.txt` |
| No `chmod` | the env file holds your keys | the ACL is reset to "this user, full control", inheritance removed; if that fails the kit tells you the `icacls` command |
| Line endings | CRLF breaks bash inside WSL; LF breaks `cmd.exe` | `.gitattributes` pins both, and the gate fails if a `.cmd` is not CRLF or a shell script contains CR |
| Argument quoting | `%*` in a `.cmd` is not lossless for exotic quoting | documented, not hidden: if an argument with embedded quotes misbehaves, call the CLI directly or use WSL |
| Python | `python` may be the Microsoft Store alias stub | `Get-Python` probes `python3`, `python`, `py -3` and requires a real `Python 3` banner; the doctor reports the interpreter it would actually use. The bash side does the same with `agentkit_python` |
| Script encoding | Windows PowerShell 5.1 reads a BOM-less `.ps1`/`.psm1` as ANSI: the UTF-8 em dash ends in byte `0x94`, read as a closing quote, so the module fails to parse | every PowerShell source is ASCII-only; the gate checks it and parses the layer with `powershell.exe` when present |
| Vendor installers that report success anyway | Cursor's `install.ps1` prints its success banner even when its download fails (seen with a flaky DNS resolver) | after a scripted install, `.\install.ps1` reloads the user `Path` and checks for the binary; if it is missing it says so and adds a to-do |
| Grok's `agent.exe` | the Grok installer **prepends** `%USERPROFILE%\.grok\bin` to the user `Path`, so `agent` is Grok even after Cursor is installed | `cursorx` resolves `cursor-agent` itself and never runs Grok; `agentkit status` prints a note |
| npm `allowScripts` | recent npm skips unapproved `postinstall` scripts (`cline`, `opencode-ai`) and warns | the CLIs still ran on the verified host; if one does not, `npm approve-scripts <pkg>` and reinstall |

## Herdr on Windows

Herdr has a **native Windows x86_64 build** (verified: herdr 0.9.1 on
Windows 11, 2026-10-03). `.\install.ps1 -Onboard` installs it with the vendor's
PowerShell installer when it is missing; the other install paths are in
[`herdr/02-install-and-update.md`](herdr/02-install-and-update.md). Two other
setups remain sensible:

- run **Herdr inside WSL2** (`curl -fsSL https://herdr.dev/install.sh | sh` in
  the distro) when your agents and repositories live there, or
- run Herdr on a **remote Linux host or container** and attach to it — see
  [`herdr/04-machines-and-ssh.md`](herdr/04-machines-and-ssh.md), and for
  reaching it from a phone [`herdr/10-tailscale-and-termius.md`](herdr/10-tailscale-and-termius.md)
  or [`herdr/11-cloudflare-tunnel-and-termius.md`](herdr/11-cloudflare-tunnel-and-termius.md).

A Windows host cannot be a **Tailscale SSH** server; use the Windows OpenSSH
Server over the tailnet instead.

Making this machine reachable from a phone (Termius) or from a Herdr hub
through a Cloudflare Tunnel is a runbook of its own, written for an agent on
this machine: [`herdr/13-windows-host-via-cloudflare-tunnel.md`](herdr/13-windows-host-via-cloudflare-tunnel.md).

One consequence worth knowing: Herdr identifies an agent by the **foreground
process** in the pane. The Unix wrappers `exec` the real CLI, so `claudex` is
detected as Claude Code. A Windows `.cmd` shim stays as a parent process, so
detection may report the shim instead. If that happens, label the command with
`HERDR_AGENT=<kind>` — see [`herdr/07-integrations.md`](herdr/07-integrations.md).

## SSH on Windows

The Windows OpenSSH client and the one inside WSL have **separate** config files
and key stores. This is the most common source of "it works in one terminal and
not the other".

```powershell
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\id_ed25519
notepad $env:USERPROFILE\.ssh\config        # Include ~/.ssh/config.d/coding-agents-kit
```

OpenSSH refuses a private key whose ACL lets other users read it — the Windows
equivalent of "permissions are too open". Fix it with `icacls`:

```powershell
icacls "$env:USERPROFILE\.ssh\id_ed25519" /inheritance:r /grant:r "$env:USERNAME:R"
```

Before picking a port for a container, check what already listens:

```powershell
Get-NetTCPConnection -LocalPort 22029 -State Listen -ErrorAction SilentlyContinue |
  ForEach-Object { Get-Process -Id $_.OwningProcess }
```

## Uninstalling

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\coding-agents-kit"
# then remove that bin path from your user Path (System Properties > Environment Variables)
# your env file in %APPDATA%\coding-agents-kit is left alone on purpose
```
