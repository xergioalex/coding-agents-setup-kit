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
> `tests/run.sh` on macOS and Linux. The Windows layer is checked **statically**
> (every wrapper has a shim, the dispatcher handles every name, encodings are
> right) and is parsed by `pwsh` when `pwsh` is installed on the machine running
> the gate. Nothing in `win/` has been executed on a Windows machine by the
> author. Treat it as `unverified on host`, run `.\install.ps1 -Onboard` and
> `agentkit status` first, and please open an issue with what you find.

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
| Python | `python` may be the Microsoft Store alias stub | `Get-Python` probes `python3`, `python`, `py -3` and requires a real `Python 3` banner |

## Herdr on Windows

Check <https://herdr.dev/docs/install/> for the current platform list before
assuming anything. If there is no native Windows build, the honest setup is:

- run **Herdr inside WSL2** (`curl -fsSL https://herdr.dev/install.sh | sh` in
  the distro) and use Windows Terminal as the outer terminal, or
- run Herdr on a **remote Linux host or container** and attach to it, which is
  what [`herdr/04-machines-and-ssh.md`](herdr/04-machines-and-ssh.md) describes.

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
