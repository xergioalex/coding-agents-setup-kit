# 12. Herdr across machines: Cloudflare Mesh + Termius

[Page 11](11-cloudflare-tunnel-and-termius.md) reaches **one** host through a
Cloudflare Tunnel (`cloudflared`). This page is the other Cloudflare shape: a
**private device-to-device network**. A Mac acts as the Herdr hub, other
machines (Windows, a Raspberry Pi or any Linux box) are Herdr nodes, and a phone
running Termius reaches all of them — every hop over **Cloudflare Mesh**, with no
public IP, no router port forward and no `cloudflared` per machine.

> **Status: alternative, unverified on host.** The setup that was actually run
> end to end is the tunnel recipe on [page 11](11-cloudflare-tunnel-and-termius.md),
> which reaches each host through its own tunnel and a loopback address. Mesh
> needs organisation-wide settings (unique device IPs, device-to-device traffic)
> that a shared Zero Trust organisation may not want; prefer page 11 there.

```
                    Cloudflare Zero Trust  ·  Cloudflare Mesh (100.96.0.0/12)
                                         │
          ┌──────────────────┬───────────┴──────┬────────────────────┐
          ▼                  ▼                  ▼                    ▼
   phone (Termius)     Mac — Herdr hub    Windows — node       Pi / Linux — node
   Cloudflare One      Cloudflare One     Cloudflare One       Mesh node (warp-cli)
                             │
                             ├── ssh over Mesh ──► Windows    (herdr --remote / saved machine)
                             └── ssh over Mesh ──► Pi / Linux
```

The property this design buys: **client off ⇒ no SSH.** Each device reaches the
others only through its Mesh IP, which exists only while the Cloudflare One
Client (formerly *WARP*) is connected. Section 7 makes that true on the LAN too.

Sources (read 2026-10-03):
<https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-mesh/get-started/> ·
<https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-mesh/client-devices/> ·
<https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-mesh/tips/> ·
<https://developers.cloudflare.com/mesh/concepts/> ·
<https://developers.cloudflare.com/cloudflare-one/traffic-policies/network-policies/>.
Checked on a Mac against `warp-cli 2026.7.1376.0`, `cloudflared 2026.9.3` and
`herdr 0.9.1`. The end-to-end flow — enrollment, the Windows and Pi steps, the
firewall hardening — is **unverified on host**; dashboard menu names change, so
follow the linked page when they differ.

## Mesh, Tunnel or Tailscale?

| | Cloudflare Mesh (this page) | Cloudflare Tunnel ([page 11](11-cloudflare-tunnel-and-termius.md)) | Tailscale ([page 10](10-tailscale-and-termius.md)) |
| --- | --- | --- | --- |
| Shape | every device gets a private IP; any-to-any | one host published behind `cloudflared` | every device gets a private IP; any-to-any |
| Per machine | the Cloudflare One Client (or `warp-cli` as a Mesh node) | `cloudflared` on the host | the Tailscale app |
| Termius | yes, to the Mesh IP | only with the Cloudflare One Agent on the phone | yes |
| Fits when | several machines, a hub, Cloudflare already your identity layer | one host, laptops with `cloudflared` | you already run a tailnet |

**Pick one private network per device.** Cloudflare lists Tailscale, WireGuard
and other VPN clients as incompatible with Mesh on the same machine (traffic may
take the wrong tunnel or fail), and Tailscale's `100.64.0.0/10` contains the
Mesh range. If a machine runs both today, quit one before testing the other.
`cloudflared` itself can coexist only through Split Tunnels (see the tips page).

## 1. Turn on Mesh in Zero Trust (dashboard, once)

1. **Networking → Mesh → Add participant**. The wizard sets up what Mesh
   needs: a *device enrollment policy*, a *device profile* whose Split Tunnels
   send `100.96.0.0/12` through Cloudflare, **Allow all Cloudflare One traffic
   to reach enrolled devices**, **Assign a unique IP address to each device**,
   and the **Gateway proxy** for TCP/UDP (ICMP optional — turn it on if you want
   `ping` for diagnostics).
2. Keep the device profile's tunnel protocol on **MASQUE** (the default); Mesh
   features such as hostname routes need it.
3. **Split Tunnels** on every profile that applies to these devices:
   - *Include* mode: `100.96.0.0/12` must be in the list.
   - *Exclude* mode: `100.96.0.0/12` must not be excluded — and not hidden
     inside a broader exclusion such as `100.64.0.0/10`. The default exclude
     list carries private ranges (`10.0.0.0/8`, …) but not this one.

   Change only that entry; leave unrelated Split Tunnel rules alone.

The **Mesh** overview page then lists each participant with its **Mesh IP** and
an *Online* state. Those addresses are the only ones the rest of this page uses —
read them there; never guess them.

## 2. Enroll each device

| Device | How | Check |
| --- | --- | --- |
| **Mac (hub)** | install the Cloudflare One Client from the wizard link, choose **Cloudflare Zero Trust**, enter the team name, log in | `warp-cli status` → *Connected*; `warp-cli registration organization` → your team |
| **Windows (node)** | same client, same login | tray icon *Connected*; the Mesh page shows the device *Online* |
| **Raspberry Pi / Linux (node)** | headless: enroll as a **Mesh node** with the token the wizard shows — Cloudflare documents `sudo warp-cli --accept-tos connector new <TOKEN> && sudo warp-cli --accept-tos connect` | `warp-cli status` on the Pi; *Online* in the dashboard |
| **Phone** | install **Cloudflare One Agent** (App Store / Google Play), enroll in the same team | switch on; *Online* in the dashboard |

The `connector` subcommand belongs to the Linux node package: the macOS
`warp-cli 2026.7` does not have it, so do not run it on the Mac. A Mesh node runs
in *Traffic and DNS* mode — keep it off a machine that serves DNS itself.

Name the devices so the Mesh table reads well, for example `herdr-hub`,
`herdr-win`, `herdr-pi`, `phone`.

Write down the addresses you read from the dashboard (no real ones go in this
repository):

```text
HUB_MESH_IP=100.9x.x.x      # the Mac
WIN_MESH_IP=100.9x.x.x
PI_MESH_IP=100.9x.x.x
```

## 3. SSH servers on each machine

Key authentication everywhere; turn off passwords only **after** a key login
works.

**Mac (hub)** — *System Settings → General → Sharing → Remote Login* on, and
*Allow access for* limited to your user. Validate any edit to
`/etc/ssh/sshd_config` with `sudo sshd -t` before relying on it.

**Windows (node)** — elevated PowerShell:

```powershell
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'   # State: Installed?
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0               # only if NotPresent
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# Windows Firewall blocks inbound Mesh traffic by default: allow SSH from the Mesh range only.
if (-not (Get-NetFirewallRule -DisplayName 'Cloudflare Mesh SSH' -ErrorAction SilentlyContinue)) {
  New-NetFirewallRule -DisplayName 'Cloudflare Mesh SSH' -Direction Inbound -Protocol TCP `
    -LocalPort 22 -RemoteAddress 100.96.0.0/12 -Action Allow
}
```

An administrator account reads its keys from
`C:\ProgramData\ssh\administrators_authorized_keys`, not from the profile's
`.ssh\authorized_keys` — the usual reason a correct key is refused. Herdr on
Windows: [`02-install-and-update.md`](02-install-and-update.md).

**Raspberry Pi / Linux (node)**:

```bash
uname -m; . /etc/os-release; echo "$PRETTY_NAME"
systemctl status ssh || sudo systemctl enable --now ssh
sudo sshd -t
```

## 4. Keys: one per trust domain

```
Mac key  "herdr-hub"   ──► authorized on Windows and the Pi
Termius key "phone"    ──► authorized on the Mac, Windows and the Pi
```

Never copy a private key between devices; each device generates its own and
only the **public** half moves.

```bash
ssh-keygen -t ed25519 -C herdr-hub -f ~/.ssh/herdr_hub_ed25519     # on the Mac
cat ~/.ssh/herdr_hub_ed25519.pub                                    # public half only
```

In Termius: **Keychain → Key → Generate** (Ed25519), then *Export to host* or
copy the public key into each machine's `authorized_keys`.

## 5. The hub's `~/.ssh/config`

Back up first (`cp ~/.ssh/config ~/.ssh/config.bak-$(date +%Y%m%d-%H%M%S)`), then
add — never replace — one block per node, using the **Mesh IP**, never a LAN
address:

```sshconfig
Host herdr-win
  HostName <WIN_MESH_IP>
  User <windows-user>
  IdentityFile ~/.ssh/herdr_hub_ed25519
  IdentitiesOnly yes

Host herdr-pi
  HostName <PI_MESH_IP>
  User <pi-user>
  IdentityFile ~/.ssh/herdr_hub_ed25519
  IdentitiesOnly yes
```

If Herdr already knows these machines under other aliases, keep those names and
point their `HostName` at the Mesh IP instead — Herdr never notices the
network changed.

## 6. Verify, then hand the paths to Herdr

With the client connected on both ends, test layer by layer — TCP first, then
SSH, then Herdr:

```bash
nc -vz <WIN_MESH_IP> 22          # TCP reachability (Windows side: Test-NetConnection <ip> -Port 22)
ssh herdr-win hostname           # handshake, host key, key auth
ssh herdr-pi 'hostname; whoami'
herdr --remote herdr-win          # interactive attach
herdr machine add herdr-pi --label "Pi"    # or save it for the sidebar
herdr machine list
```

`ping` needs the Gateway's ICMP proxy; a failed ping proves nothing about TCP 22.
Saved machines and remote attach: [`04-machines-and-ssh.md`](04-machines-and-ssh.md).

**Termius** (phone, Cloudflare One Agent on): one host per machine — Hostname =
its Mesh IP, Port `22`, the user, the *phone* key — and optionally a Startup
Command `herdr` so connecting lands in Herdr
([page 10, section 4](10-tailscale-and-termius.md)).

**The off-switch test.** It is the point of the design, so record it:

| From | To | Client state | Expected |
| --- | --- | --- | --- |
| Mac | `herdr-win` / `herdr-pi` | all on | pass |
| phone | Mac, Windows, Pi Mesh IPs | all on | pass |
| Mac | `herdr-win` | Windows client **off** | fail |
| Mac | `herdr-pi` | Pi node **disconnected** (`sudo warp-cli disconnect`) | fail |
| Mac | any Mesh IP | Mac client **off** (`warp-cli disconnect`) | fail |
| phone | any Mesh IP | phone agent **off** | fail |
| Mac | Windows / Pi **LAN** IP, port 22 | any | fail *after section 7* |

Turn each client back on and confirm the path returns.

## 7. Close the LAN bypass (only after section 6 passes)

Using Mesh IPs does not stop sshd from also answering on `192.168.x.x`. Until
the host firewall restricts TCP 22, "client off ⇒ no SSH" holds for remote
networks but not for the same LAN. Do this **one machine at a time**, with
physical or console access to it, in this order: show the current rules → add
the Mesh allow → test a Mesh login → remove the broad allow → test again (Mesh
passes, LAN fails).

**Windows** — the section 3 rule is the Mesh allow. Find the broad ones and
disable (not delete) them:

```powershell
Get-NetFirewallRule -Enabled True -Direction Inbound | Get-NetFirewallPortFilter |
  Where-Object LocalPort -eq 22 | Get-NetFirewallRule | Select-Object Name, DisplayName, Profile
Disable-NetFirewallRule -Name OpenSSH-Server-In-TCP     # the rule the capability install created
# rollback: Enable-NetFirewallRule -Name OpenSSH-Server-In-TCP
```

**Raspberry Pi / Linux** — check which firewall is actually in charge
(`sudo ufw status`, `sudo nft list ruleset`) before touching any. With **ufw**:

```bash
sudo ufw allow from 100.96.0.0/12 to any port 22 proto tcp comment 'Cloudflare Mesh SSH'
sudo ufw status numbered                      # find the broad "22/tcp" or "OpenSSH" allow
sudo ufw delete <number>                      # remove only that one
# first time enabling ufw? add the Mesh rule BEFORE `sudo ufw enable` — default policy denies incoming
# rollback: sudo ufw allow OpenSSH
```

**Mac (hub)** — the macOS Application Firewall filters by app, not by source
address, so it cannot express "SSH from the Mesh only". Use `pf` with its own
anchor and keep `/etc/pf.conf` untouched:

```bash
sudo tee /etc/pf.anchors/mesh-ssh >/dev/null <<'EOF'
pass in quick on lo0 proto tcp to any port 22
pass in quick proto tcp from 100.96.0.0/12 to any port 22
block in quick proto tcp to any port 22
EOF
sudo pfctl -a mesh-ssh -nf /etc/pf.anchors/mesh-ssh     # parse only
```

Loading it needs a ruleset that references the anchor (`anchor "mesh-ssh"` plus
`load anchor "mesh-ssh" from "/etc/pf.anchors/mesh-ssh"`, added to a copy of
`/etc/pf.conf`, loaded with `sudo pfctl -f <copy>` and enabled with `sudo pfctl -E`).
That does not survive a reboot unless a LaunchDaemon reloads it; rollback is
`sudo pfctl -f /etc/pf.conf`. The Mac is mostly a **client** in this design —
only the phone SSHes into it — so this step is optional; Remote Login limited
to your user plus key-only auth is often enough. `pf` on the hub is
**unverified on host**.

The source-address rule cannot tell Mesh from Tailscale (both use addresses in
`100.64.0.0/10`); one more reason to run a single private network per device.

## 8. Narrow it with Gateway policies

The wizard's *Allow all Cloudflare One traffic to reach enrolled devices* lets
every enrolled device reach every other. Tighten it with a **Gateway network
policy** (*Traffic policies → Firewall policies → Network*): allow
**Destination IP** in the hub/node Mesh IPs and **Destination Port** `22` for
your **User Email** (optionally a *device posture* check), and block the rest of
`100.96.0.0/12`. The result is four gates in a row: enrolled device, Cloudflare
identity, SSH key, OS account. Policy selectors are **unverified on host** —
build it from the network-policies page above.

## Security checklist

- No port forward, no public DNS record for SSH, no `cloudflared` per machine.
- Final auth is key-only; `PermitRootLogin no`.
- The agents run this kit's **full-permission** wrappers: whoever reaches a
  node's sshd controls them. Scope the Gateway policy to yourself.
- A lost phone: revoke the device in Zero Trust **and** remove its key from
  every `authorized_keys`.
- Never paste enrollment tokens or Service Auth secrets into a repo or a log.

## When it does not connect

Work down the stack and change one layer at a time: Herdr → `ssh` → Mesh IP →
OS route → local client → Zero Trust → remote client → remote firewall → remote
sshd → `authorized_keys`.

| Symptom | Check |
| --- | --- |
| `nc -vz <mesh-ip> 22` times out | both clients connected? Device *Online* on the Mesh page? `warp-cli tunnel dump` on the Mac must **not** list `100.96.0.0/12` among the bypassed routes |
| times out only to Windows | the *Cloudflare Mesh SSH* firewall rule exists and its profile matches the active network |
| works, then breaks with Tailscale running | two VPNs on one machine; quit one |
| `Permission denied (publickey)` on Windows | an admin account reads `administrators_authorized_keys` |
| still reachable on the LAN with the client off | section 7 not done on that machine |
| saved machine in *Attention* | `ssh <alias> true` in a terminal first; see [`08-troubleshooting.md`](08-troubleshooting.md) |
