# 13. A Windows host behind the tunnel

A runbook for **an agent running on the Windows machine**, guiding its human.
It adds Windows as one more host to the setup of
[`11-cloudflare-tunnel-and-termius.md`](11-cloudflare-tunnel-and-termius.md):
the phone (Termius) and the hub (a Mac running Herdr) reach this machine's
sshd through a Cloudflare Tunnel, gated by the policies that already exist,
and the hub's Herdr shows this machine as a saved machine next to Local.

```
phone (Termius) ─┐
                 ├─► Cloudflare One client ─► Gateway: Allow (your email, :22) ─► tunnel on Windows ─► cloudflared
hub (ssh/herdr) ─┘                                                                                     │
                                                       198.18.22.2 on a loopback adapter ─► sshd ─► herdr (native)
```

**Verification record.** Executed end to end on 2026-10-03: Windows 11 25H2
(build 26200, x64), Windows PowerShell 5.1, `OpenSSH_for_Windows_9.5p2`,
`cloudflared 2026.9.3` (winget), `herdr 0.9.1` native on both the Windows host
and the macOS hub. Verified: Termius → Windows shell through the tunnel; the
hub's `ssh` with a dedicated key; **the hub's Herdr attaching to the native
Windows Herdr server**, both `herdr --remote` and as a saved machine, with
sshd's default shell left as `cmd.exe`; an unknown user refused by
`AllowUsers`; no firewall rule needed for the tunnel. The machine had been
reached over Tailscale before, and that path was removed (section 10).
**Not yet verified:** the path surviving a Windows reboot, and
`AllowTcpForwarding no` (left at the default). Record those here when done.

Sources (read 2026-10-03):
<https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse> ·
<https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_keymanagement> ·
<https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-server-configuration> ·
<https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/> ·
<https://winstall.app/apps/Cloudflare.cloudflared>.

## Placeholders

Nothing on this page is anybody's real value.

| Placeholder | Meaning |
| --- | --- |
| `198.18.22.0/24` | the person's address block from page 11 |
| `198.18.22.2` | **this** machine's address in it (`.1` is usually the hub) |
| `you` | the Windows account people log in as |
| `my-windows` | the tunnel name |
| `win` | the SSH alias on the hub (any name works) |
| `mac-to-windows`, `termius-phone` | key comments |

## What already exists (do not redo)

From page 11, in the Zero Trust dashboard: the person's **Allow** policy on
their `/24`, port 22 (with the shared **Block** under it), the shared
**device profile** the phone and hub use, and the Gateway TCP proxy. This
machine needs **no new policy, no profile change, and no Cloudflare One
Client**: it only receives connections, through `cloudflared`.

## Rules while guiding

- **Elevated PowerShell** (*Run as administrator*) for every step that changes
  the system. The human runs it and pastes back the output; an agent's shell is
  normally not elevated.
- **Look before changing**: every step starts with a read-only check.
- **Never** print the tunnel token, a private key, or a full public key into the
  chat or the repository. Show key *comments* and *types* only.
- Dashboard steps happen in the human's browser; confirm each screen before
  they press Save.
- Ask for the address, the account, the tunnel name and the public keys; never
  guess them.

## 1. Inspect (read-only)

```powershell
[Environment]::OSVersion.Version; $env:PROCESSOR_ARCHITECTURE
& "$env:WINDIR\System32\whoami.exe"
& "$env:WINDIR\System32\whoami.exe" /groups | Select-String 'S-1-5-32-544'   # present = administrator
Get-Service sshd, cloudflared, Tailscale -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType
Get-Content "$env:ProgramData\ssh\sshd_config" | Select-String '^\s*(ListenAddress|AllowUsers|PasswordAuthentication|Match)'
Get-NetTCPConnection -State Listen -LocalPort 22 -ErrorAction SilentlyContinue | Select-Object LocalAddress
Get-NetFirewallRule | Where-Object { $_.DisplayName -like '*ssh*' -or $_.DisplayName -like '*ailscale*' } | Select-Object Name, DisplayName, Enabled
Get-NetAdapter | Select-Object Name, InterfaceDescription, Status
Get-Command cloudflared, herdr -ErrorAction SilentlyContinue
```

Pitfalls seen while inspecting:

- **Use `whoami.exe` by full path.** From Git Bash, or with Git's `usr\bin` on
  PATH, `whoami` is the MSYS one and `whoami /groups` fails, which looks like
  "not an administrator".
- `Get-WindowsCapability` (is OpenSSH Server installed?) **needs elevation**;
  `Test-Path "$env:WINDIR\System32\OpenSSH\sshd.exe"` and `Get-Service sshd`
  answer the same question without it.
- **"sshd is Running" is not "port 22 answers".** A previous setup may bind sshd
  to one address only (`ListenAddress`); check what it listens on.
- Reading `administrators_authorized_keys` and the host key needs elevation.

Report a short table of what exists and what is missing, then go step by step.

## 2. OpenSSH Server

Skip what step 1 showed as done.

```powershell
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0   # only if missing
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
```

Leave the built-in `OpenSSH-Server-In-TCP` firewall rule **disabled**: nothing
on the LAN should reach port 22 (section 8 explains why the tunnel needs no
rule). The default SSH shell stays `cmd.exe`; that was enough for Herdr.

## 3. Install `cloudflared`

```powershell
winget install --id Cloudflare.cloudflared       # confirm the id with: winget search cloudflared
cloudflared --version                            # in a NEW terminal
```

Windows does **not** auto-update `cloudflared`; update with
`winget upgrade --id Cloudflare.cloudflared`.

## 4. Give this machine its address

The address must belong to the machine and never depend on the network it is
on. Windows' built-in loopback takes no extra addresses, so add a **loopback
adapter**:

1. `hdwwiz.exe` → *Install the hardware that I manually select from a list
   (Advanced)* → *Network adapters* → **Microsoft** → **Microsoft KM-TEST
   Loopback Adapter** → finish. Windows names it like a NIC (`Ethernet 2`, …).
2. Give it the address:

   ```powershell
   $a = (Get-NetAdapter | Where-Object InterfaceDescription -like '*KM-TEST*').Name
   New-NetIPAddress -InterfaceAlias $a -IPAddress 198.18.22.2 -PrefixLength 32
   ```

Undo: `Remove-NetIPAddress -IPAddress 198.18.22.2 -Confirm:$false`, then remove
the adapter in Device Manager. Do **not** fall back to the Wi-Fi/Ethernet
address: it changes between networks and the default Split Tunnels exclude it.

## 5. sshd: listen only on that address, keys only

Back up, then make the end of `C:\ProgramData\ssh\sshd_config` look like this.
Global settings must sit **above** the `Match Group administrators` block,
which must stay last:

```
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
AllowUsers you
ListenAddress 198.18.22.2
MaxAuthTries 3
LoginGraceTime 30
AllowAgentForwarding no
X11Forwarding no
GatewayPorts no
Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

```powershell
$c = "$env:ProgramData\ssh\sshd_config"
Copy-Item $c "$c.bak-$(Get-Date -Format yyyyMMdd-HHmmss)"
notepad $c
& "$env:WINDIR\System32\OpenSSH\sshd.exe" -t      # no output = valid
Restart-Service sshd
Get-NetTCPConnection -State Listen -LocalPort 22 | Select-Object LocalAddress   # only 198.18.22.2
```

- **`ListenAddress` on the tunnel address only** means sshd is unreachable from
  the Wi-Fi or the LAN at all; `cloudflared` is the only way in.
- **Order matters if this machine used another private network before.** If an
  old `ListenAddress` points at an address that is about to disappear (a
  Tailscale `100.x`, for example), **replace** it in the same edit. A
  `ListenAddress` that does not exist at boot stops sshd from starting.
- The address must already exist (step 4) before `Restart-Service sshd`.

Undo: copy the `.bak` back and `Restart-Service sshd`.

## 6. The tunnel and its route

The human, in the dashboard: **Networks → Tunnels → Create a tunnel** →
*Cloudflared* → name (`my-windows`) → environment **Windows** → copy the
*install as a service* command. **Skip** the public-hostname step.

On this machine, elevated — the human pastes the command; the token never goes
through the agent:

```powershell
cloudflared.exe service install <token>
Get-Service cloudflared                          # Running, Automatic
```

Back in the dashboard: the connector shows **Healthy**. Then that tunnel →
**CIDR routes → Add** → `198.18.22.2/32`, virtual network `default`. The
person's existing Allow already covers it because it lies inside their `/24`.

Undo: delete the route and the tunnel in the dashboard, then
`cloudflared.exe service uninstall`.

## 7. Authorize keys — one per device

The account is an **administrator** in the usual case, so keys go in
`C:\ProgramData\ssh\administrators_authorized_keys`; the profile's
`.ssh\authorized_keys` is **ignored** for administrators (a standard account
uses `C:\Users\you\.ssh\authorized_keys` instead).

**Make the hub's key on the hub** (the private half never leaves it):

```bash
ssh-keygen -t ed25519 -C mac-to-windows -f ~/.ssh/windows_ed25519   # set a passphrase
cat ~/.ssh/windows_ed25519.pub                                      # only this line travels
```

The phone's key is generated in Termius (*Keychain → Key*) and exported as its
public line the same way.

**Add each public line on Windows**, elevated — append, never overwrite:

```powershell
$f = "$env:ProgramData\ssh\administrators_authorized_keys"
if (Test-Path $f) { Copy-Item $f "$f.bak-$(Get-Date -Format yyyyMMdd-HHmmss)" }
Add-Content -Path $f -Value 'from="198.18.22.2" ssh-ed25519 AAAA... mac-to-windows'
Add-Content -Path $f -Value 'from="198.18.22.2" ssh-ed25519 AAAA... termius-phone'
icacls.exe $f /inheritance:r /grant '*S-1-5-32-544:F' /grant '*S-1-5-18:F'
Get-Content $f | ForEach-Object { ($_ -split ' ')[-1] }           # comments only
```

- **`from="198.18.22.2"`**: connections through the tunnel reach sshd with the
  machine's **own tunnel address as source** (verified in the sshd log), so
  this option makes a key usable only through the tunnel — even if port 22
  were ever opened by mistake.
- The `icacls` line uses SIDs (Administrators, SYSTEM), so it works on
  non-English Windows; sshd refuses the file with looser permissions.
- Each key on **one line**.

## 8. Firewall: nothing to add

`cloudflared` connects to `198.18.22.2:22` from the same machine, and Windows
Firewall did not filter that: with the built-in OpenSSH rule disabled and no
other SSH rule, phone and hub both connected. Remove rules left by previous
setups that open port 22 to some network (section 10), and add none.

## 9. The hub: SSH alias, then Herdr

On the hub (its Cloudflare One Client connected), append to `~/.ssh/config`
after backing it up:

```sshconfig
Host win
  HostName 198.18.22.2
  User you
  IdentityFile ~/.ssh/windows_ed25519
  IdentitiesOnly yes
  ServerAliveInterval 30
  UseKeychain yes
  AddKeysToAgent yes
```

`UseKeychain` / `AddKeysToAgent` (macOS) remember the passphrase: Herdr's
background connections cannot ask for it. Do **not** set
`UserKnownHostsFile /dev/null`; saved machines check host keys strictly.

```bash
ssh win hostname             # first time: verify the host key (below), then "yes"
ssh win herdr --version      # Windows' herdr is found through the user PATH
herdr --remote win           # interactive once; answer No to any install/replace prompt
herdr machine add win --label "Windows"
```

**Verify the host key before typing `yes`.** On Windows, elevated:

```powershell
& "$env:WINDIR\System32\OpenSSH\ssh-keygen.exe" -lf "$env:ProgramData\ssh\ssh_host_ed25519_key.pub"
```

The fingerprint must equal the one `ssh` printed on the hub. If you already
accepted a wrong one: `ssh-keygen -R 198.18.22.2` on the hub.

Herdr 0.9.1 on macOS attached to the native Windows Herdr server with
`cmd.exe` as the SSH default shell — no `DefaultShell` change, no WSL. In the
Windows server log a saved machine shows up as clients with
`surface_active=false` (background) plus the attached UI.

## 10. Coming from Tailscale: remove it cleanly

If the machine was reachable over Tailscale before, finish sections 1–9 first
(the hub keeps its old path meanwhile), then, elevated:

```powershell
Get-NetFirewallRule | Where-Object DisplayName -like '*ailscale*' | Select-Object Name, DisplayName
Remove-NetFirewallRule -Name '<the rule that opened port 22 to the tailnet>'
tailscale logout
winget uninstall --id Tailscale.Tailscale
Get-Service Tailscale -ErrorAction SilentlyContinue        # nothing
```

Outside this machine: remove the devices in the Tailscale admin console,
uninstall the app on the hub and the phone, and delete hosts that point at
`100.x` addresses from the hub's `~/.ssh/config` and from Termius. Remove keys
that only existed for the old path from `administrators_authorized_keys`.

## 11. Verify

| Test | Expected |
| --- | --- |
| Termius → `198.18.22.2`, agent on | a Windows shell, no password |
| Termius, agent off | timeout |
| hub `ssh win hostname` | the Windows host name |
| hub `ssh nobody@win` or any user not in `AllowUsers` | refused (`Invalid user` in the sshd log) |
| hub Herdr | **Windows** listed next to Local, its panes live |
| `Get-NetTCPConnection -State Listen -LocalPort 22` | only `198.18.22.2` |
| Windows rebooted and signed in | all of the above again — **not yet verified** |

The sshd log is the fastest evidence (read-only):

```powershell
Get-WinEvent -LogName 'OpenSSH/Operational' -MaxEvents 20 | Sort-Object TimeCreated |
  ForEach-Object { "{0:HH:mm:ss}  {1}" -f $_.TimeCreated, ($_.Message -replace '\s+', ' ') }
```

## When it does not connect

| Symptom | Meaning / fix |
| --- | --- |
| hub/phone time out | tunnel *Healthy*? CIDR route `/32` on **this** tunnel? client connected on the hub/phone? |
| `Permission denied (publickey)`; sshd log: `Connection closed by authenticating user … [preauth]` | the network path works; the key offered is **not authorized**. Check the file's last write time and its comments; an administrator's key must be in `administrators_authorized_keys`, on one line, with the `icacls` ACL. `ssh -v win` on the hub shows which key it offers |
| key authorized with `from=` but still refused | the source address sshd sees is not the one in `from=`; read it from an `Accepted`/`closed` line in the sshd log |
| sshd does not start after a reboot | a `ListenAddress` names an address that is gone (old private network, adapter removed) |
| `ssh win herdr --version` says herdr is not recognized | the SSH session does not see the user PATH; check `[Environment]::GetEnvironmentVariable('Path','User')` contains Herdr's release directory |
| hub warns *connection is not using a post-quantum key exchange algorithm* | a warning, not an error: Windows' bundled OpenSSH 9.5 does not offer the post-quantum key exchange a recent macOS client asks for. The session is still encrypted, inside the tunnel's own encryption. It goes away with a newer OpenSSH on Windows |

## When something changes

Update the verification record at the top with the date, Windows build,
`cloudflared` and Herdr versions and anything that behaved differently, then
run `tests/run.sh` before committing.
