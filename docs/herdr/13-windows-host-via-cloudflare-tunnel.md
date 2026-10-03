# 13. Next steps: add a Windows host behind the tunnel

A runbook for **an agent running on the Windows machine**, guiding its human.
It adds Windows as one more host to the setup of
[`11-cloudflare-tunnel-and-termius.md`](11-cloudflare-tunnel-and-termius.md):
the phone (Termius) and the hub (usually a Mac running Herdr) reach this
machine's sshd through a Cloudflare Tunnel, gated by the policies that already
exist.

```
phone (Termius) ─┐
                 ├─► Cloudflare One client ─► Gateway: Allow (your email, :22) ─► tunnel on Windows ─► cloudflared
hub (ssh/herdr) ─┘                                                                                     │
                                                         198.18.100.2 on a loopback adapter ─► sshd ─► herdr
```

**Status: unverified on host.** Page 11 was run end to end on macOS; nothing
on this page has been run on Windows yet. Each step says how to check it and
how to undo it. Record what actually happened (versions, menu names, errors)
in this page when you are done — that is how it becomes verified.

Sources (read 2026-10-03):
<https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse> ·
<https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement> ·
<https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-server-configuration> ·
<https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/> ·
<https://winstall.app/apps/Cloudflare.cloudflared>.

## What already exists (do not redo)

From page 11, in the Zero Trust dashboard:

- the **Allow** policy for this person on their `/24` (for example
  `198.18.100.0/24`), port 22, their email — and the shared **Block** under it;
- the shared **device profile** (MASQUE) that the person's phone and hub use;
- the Gateway TCP proxy.

This machine needs **no new policy and no profile change**. It does **not**
need the Cloudflare One Client either: it only receives connections, through
`cloudflared`.

## Ask the human first

Do not guess these; ask, and keep them out of the repository:

| Input | Example | Used in |
| --- | --- | --- |
| The person's address block | `198.18.100.0/24` | step 6 |
| The address for **this** machine, free in that block | `198.18.100.2` (`.1` is usually the hub) | steps 6–7 |
| The Windows account to log in as, and whether it is an **administrator** | `you`, admin | step 3 |
| The public keys to authorize: the phone's Termius key and the hub's key | `ssh-ed25519 AAAA… termius-phone` | step 3 |
| A name for the tunnel | `my-windows` | step 7 |

Rules while guiding:

- **Elevated PowerShell** (Run as administrator) for every step that changes
  the system. The human runs it; show the command, then read back the output.
- **Look before changing**: every step starts with a read-only check.
- **Never** print or paste the tunnel token; it is a secret. Mask it when you
  inspect processes or services.
- Dashboard steps are done by the human in a browser; confirm each screen from
  a screenshot **before** they press Save. Names and descriptions typed there
  in English.
- The kit's own rules apply: no real values in the repo, no `$HOME` changes the
  human did not ask for.

## 1. Inspect (read-only)

```powershell
[Environment]::OSVersion.Version; $env:PROCESSOR_ARCHITECTURE; whoami
whoami /groups | Select-String 'S-1-5-32-544'          # present = this account is an administrator
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
Get-Service sshd, cloudflared -ErrorAction SilentlyContinue
Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue | Select-Object Name, Enabled, Profile
Get-Command cloudflared, herdr -ErrorAction SilentlyContinue
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status
Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -like '198.18.*'
Get-Command tailscale -ErrorAction SilentlyContinue      # another private network fights for routes
```

Report a short table of what exists and what is missing, then go step by step.

## 2. OpenSSH Server

Skip what step 1 showed as already done.

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0   # only if State is NotPresent
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
Test-NetConnection 127.0.0.1 -Port 22                            # TcpTestSucceeded : True
```

Undo: `Stop-Service sshd; Set-Service sshd -StartupType Disabled`.

**Default shell (optional).** OpenSSH on Windows starts `cmd.exe`. PowerShell
is friendlier from Termius:

```powershell
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell `
  -Value 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' -PropertyType String -Force
# undo: Remove-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell
```

Whether Herdr's remote attach from the hub prefers a particular shell is
**not known yet** — see step 9.

## 3. Authorize the keys

Which file depends on the account (Microsoft's key-management page):

- **Administrator** account: `C:\ProgramData\ssh\administrators_authorized_keys`,
  readable only by Administrators and SYSTEM. The profile's
  `.ssh\authorized_keys` is **ignored** for administrators — the usual reason a
  correct key is refused.
- **Standard** account: `C:\Users\<account>\.ssh\authorized_keys`.

Administrator case — append, never overwrite; SIDs instead of group names so
it also works on non-English Windows:

```powershell
$f = "$env:ProgramData\ssh\administrators_authorized_keys"
if (Test-Path $f) { Copy-Item $f "$f.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" }
Add-Content -Path $f -Value 'ssh-ed25519 AAAA... termius-phone'
Add-Content -Path $f -Value 'ssh-ed25519 AAAA... herdr-hub'
icacls.exe $f /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F'
Get-Content $f | ForEach-Object { ($_ -split ' ')[0,-1] -join ' ' }   # type and comment only
```

Each key on **one line**. Only public keys (`ssh-ed25519 AAAA…`) ever travel;
private keys stay on the device that made them.

The **hub's key**, if the hub does not have one for this purpose yet, is made
on the hub, not here: `ssh-keygen -t ed25519 -C herdr-hub -f ~/.ssh/herdr_hub_ed25519`
on the Mac, then its `.pub` line comes to this step.

## 4. Herdr on Windows

From a clone of this kit: `.\install.ps1 -Onboard` installs Herdr natively
when it is missing ([`../WINDOWS.md`](../WINDOWS.md),
[`02-install-and-update.md`](02-install-and-update.md)). Check with
`herdr --version` in a **new** terminal.

## 5. Install `cloudflared`

```powershell
winget search cloudflared                       # confirm the id is Cloudflare.cloudflared
winget install --id Cloudflare.cloudflared
# open a new terminal, then:
cloudflared --version
```

Record the version here when it works. Windows does **not** auto-update
`cloudflared` (Cloudflare's downloads page); updating is a manual `winget
upgrade`.

## 6. Give this machine its address

The address (`198.18.100.2`) must belong to this machine and never depend on the
Wi-Fi it is on — the same idea as the macOS loopback alias in page 11,
section 3. Windows has no extra addresses on its built-in loopback, so add a
**loopback adapter**:

1. Run `hdwwiz.exe` → *Install the hardware that I manually select from a
   list (Advanced)* → *Network adapters* → manufacturer **Microsoft** →
   **Microsoft KM-TEST Loopback Adapter** → finish.
2. Find its name and give it the address:

   ```powershell
   Get-NetAdapter | Where-Object InterfaceDescription -like '*KM-TEST*'
   New-NetIPAddress -InterfaceAlias '<that adapter name>' -IPAddress 198.18.100.2 -PrefixLength 32
   Test-NetConnection 198.18.100.2 -Port 22          # TcpTestSucceeded : True
   ```

Undo: `Remove-NetIPAddress -IPAddress 198.18.100.2 -Confirm:$false`, then remove
the adapter in Device Manager. The address persists across reboots on its own.

If the adapter cannot be installed, stop and report; do **not** fall back to
the Wi-Fi/Ethernet address without the human deciding it (that address changes
between networks and is excluded by the default Split Tunnels).

## 7. The tunnel and its route (dashboard + this machine)

The human, in the dashboard: **Networks → Tunnels & Mesh → Create a tunnel** →
*Cloudflared* → name (`my-windows`) → environment **Windows** → copy the
*install as a service* command. **Skip** the public-hostname step.

On this machine, in elevated PowerShell — the human pastes the command; the
token never goes through the agent:

```powershell
cloudflared.exe service install <token>
Get-Service cloudflared                          # Running, StartupType Automatic
```

Back in the dashboard: the connector shows **Connected** (*Healthy*). Then that
tunnel → **CIDR routes → Add CIDR route** → `198.18.100.2/32`, a description,
virtual network `default`.

Undo: delete the route and the tunnel in the dashboard, then
`cloudflared.exe service uninstall`.

## 8. Keys only

After a key login works (step 9), stop accepting passwords. Settings must sit
**above** the `Match Group administrators` block at the end of
`C:\ProgramData\ssh\sshd_config`:

```powershell
$c = "$env:ProgramData\ssh\sshd_config"
Copy-Item $c "$c.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
notepad $c        # set, above any Match block:  PasswordAuthentication no
                  #                              KbdInteractiveAuthentication no
& "$env:WINDIR\System32\OpenSSH\sshd.exe" -t     # no output = valid
Restart-Service sshd
```

Undo: copy the `.bak` back and `Restart-Service sshd`.

## 9. Verify

From the **phone**: Termius → new host `198.18.100.2`, port 22, the Windows
account, the Termius key; Cloudflare One Agent on.

From the **hub** (Mac), whose Cloudflare One Client must be connected — on the
hub the traffic leaves through the client, unlike its own inbound path:

```bash
route -n get 198.18.100.2 | grep interface       # a utun interface (the client), not lo0
nc -z 198.18.100.2 22 && echo ok
```

Add to the hub's `~/.ssh/config` (append, back it up first):

```sshconfig
Host win
  HostName 198.18.100.2
  User <windows-account>
  IdentityFile ~/.ssh/herdr_hub_ed25519
  IdentitiesOnly yes
```

```bash
ssh win hostname                                 # key login, no password
herdr --remote win                               # see below
```

| Test | Expected |
| --- | --- |
| Termius → `198.18.100.2`, agent on | a Windows shell, no password |
| Termius, agent off | timeout |
| hub `ssh win hostname` | the Windows host name |
| password login after step 8 | refused |
| Windows rebooted and signed in | all of the above again |

**Herdr from the hub** has never been tried against a native Windows server
over SSH. If `herdr --remote win` or `herdr machine add win --label "Windows"`
fails, record the exact error here and fall back to Herdr inside **WSL2** on
this machine ([`../WINDOWS.md`](../WINDOWS.md)) — which needs its own sshd and
address, and is a separate decision for the human.

## When it does not connect

| Symptom | Check |
| --- | --- |
| `Test-NetConnection 198.18.100.2 -Port 22` fails locally | sshd running? the address on the loopback adapter? |
| phone/hub time out | tunnel connector *Healthy*? CIDR route `/32` on **this** tunnel? the person's Allow covers the block and sits above the shared Block? phone/hub client connected? |
| `Permission denied (publickey)` with the right key | administrator account → key must be in `administrators_authorized_keys` with the `icacls` ACL; key on one line |
| hub reaches the Mac but not Windows | hub's client disconnected, or `route -n get` shows the Wi-Fi interface |

## When done

Replace "unverified on host" with what was actually verified (date, Windows
build, `cloudflared` version, menu names that differed), update the page-11
section 10 summary, and run `tests/run.sh` before committing.
