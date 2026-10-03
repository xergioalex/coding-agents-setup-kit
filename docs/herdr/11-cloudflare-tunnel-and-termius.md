# 11. Herdr from anywhere: Cloudflare Tunnel + Termius

The same goal as [`10-tailscale-and-termius.md`](10-tailscale-and-termius.md) —
agents run in Herdr on a host, you attach from a phone or laptop — but the path
is a **Cloudflare Tunnel**: the host makes an outbound connection to Cloudflare,
so it needs no public IP, no router port forward and no open inbound port, and
access is gated by Cloudflare Zero Trust policies.

Several machines that should all reach each other (a hub plus nodes, a phone to
each) without a tunnel per machine? That is **Cloudflare Mesh**:
[`12-cloudflare-mesh-and-termius.md`](12-cloudflare-mesh-and-termius.md).

**Verification record.** Sections 1–9 were executed end to end on 2026-10-03:
macOS 27 host, `cloudflared 2026.9.3` (Homebrew), Cloudflare One Client
`warp-cli 2026.7.1376.0`, `herdr 0.9.1`, Termius and the Cloudflare One Agent
on iOS, inside a Zero Trust organisation that **other people also use**. The
host survived a reboot with the path intact. Section 11 describes the
multi-person layout the dashboard was then moved to (shared profile, shared
Block); onboarding a second person through it has **not** been done yet.
Section 10 (Windows and Linux hosts) is **unverified on host**. Dashboard menu names are the ones seen that
day; they move, so follow the linked page when they differ.

Sources (read 2026-10-03):
<https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/> and its child pages ·
<https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-device-client/> ·
<https://developers.cloudflare.com/cloudflare-one/traffic-policies/network-policies/> ·
<https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/download/>.

## Pick the method by client

| Method | Client needs | Laptop terminal / `herdr --remote` | Termius (phone) |
| --- | --- | --- | --- |
| **A. Public hostname + `cloudflared` on the client** | `cloudflared` and a `ProxyCommand` in `~/.ssh/config` | yes | **no** — a phone SSH app cannot run `cloudflared` as a `ProxyCommand` |
| **B. Private network + Cloudflare One Client** (this page, verified) | the Cloudflare One app enrolled in your organisation | yes | **yes** — Termius connects to a private IP as if on a LAN |
| C. Access for Infrastructure | Cloudflare One Client + short-lived SSH certificates | yes | `unverified on host` |
| D. Browser-rendered SSH | a web browser | no | no |

Method B, the way it works:

```
phone: Termius ──► Cloudflare One Agent ──► Gateway network policy ──► tunnel ──► cloudflared on the host
       ssh you@198.18.100.1                  (only your email, port 22)                   │
                                                                                         ▼
                                                     198.18.100.1 = alias on the host's loopback ──► sshd ──► herdr
```

Method A is in the [appendix](#appendix-method-a--public-hostname-laptops-only).

## Placeholders

Nothing below is anybody's real value. Replace:

| Placeholder | Meaning |
| --- | --- |
| `you@example.com` | the identity you log in to Zero Trust with |
| `you` | your account on the host |
| `my-tunnel` | the tunnel name |
| `198.18.0.0/16` | the team range: every person's block lives inside it ([section 11](#11-several-people-in-one-organisation)) |
| `198.18.100.0/24` | the address block reserved for *your* machines (section 3) |
| `198.18.100.1` | this host's address inside that block |

## 0. Before you start

- **sshd works locally.** macOS: *System Settings → General → Sharing → Remote
  Login* on, limited to your user. Check with `nc -z 127.0.0.1 22`.
- **Herdr is installed** on the host (`herdr --version`).
- **One private network per device.** The Cloudflare One Client and Tailscale
  fight over routes; quit one before testing the other.
- **A shared organisation is fine** — every change below is scoped to your
  identity or to an address block only you use. Two settings are
  organisation-wide: the Gateway **proxy** (check it, do not toggle it blindly)
  and the **order of network policies** (yours go on top). Never edit the
  **Default** device profile: everyone else uses it.

## 1. The tunnel

Look before creating anything:

```bash
ls /Library/LaunchDaemons/com.cloudflare.cloudflared.plist ~/Library/LaunchAgents/com.cloudflare.cloudflared.plist 2>/dev/null
pgrep -fl cloudflared | sed -E 's/--token [^ ]+/--token [hidden]/'
```

- **A tunnel already runs on this host** (for example one that publishes local
  dev servers): **reuse it**. Routes are independent — adding a CIDR route does
  not touch its published application routes.
- **None yet:** dashboard **Networks → Tunnels & Mesh → Create a tunnel** →
  *Cloudflared* → name `my-tunnel` → choose the OS → run the *install as a
  service* command it shows, in your own terminal. Skip the public-hostname
  step the wizard offers.

Two macOS hazards, both seen in practice:

- `sudo cloudflared service install <token>` writes
  `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist`. If that file
  already exists for another tunnel, **installing a second tunnel this way
  replaces the first one's service**. One service per host: reuse the tunnel.
- The token is a **command-line argument**: `ps` shows it to every local user.
  Never paste it into a chat, a log or a document; mask it as above when you
  inspect processes.

## 2. Why a CIDR route and not a hostname route

Cloudflare also offers **private hostname routes** (`ssh.example.internal`
style names). They failed here, and will fail on any host that runs the
Cloudflare One Client in *Traffic and DNS* mode **and** the tunnel connector:

1. The phone asks Gateway for the name; Gateway asks the tunnel to resolve it.
2. `cloudflared` resolves through the host's DNS server — which is the
   client's own local resolver (`127.0.2.2`).
3. That resolver forwards to Gateway, which asks the tunnel again: a loop.
   Gateway answers **`REFUSED`** (an unknown name gets `NXDOMAIN`).

The tunnel's **Live logs** show it: DNS flows to `[2606:4700:cf1:2000::1]:53`
handed to `127.0.2.2:53`, then closed. `cloudflared` does **not** read
`/etc/hosts` for this lookup, so a hosts entry does not help. A CIDR route
involves no DNS at all.

## 3. Give the host a private address of its own

Pick a `/24` for your machines inside `198.18.0.0/15` (RFC 2544, reserved for
benchmarking: never routed on the internet, not in Cloudflare's default Split
Tunnels exclude list, unlikely on home or office LANs). Each host gets one
address on its **loopback** interface, so the address never depends on the
Wi-Fi it is on:

```
198.18.100.1  first host     198.18.100.2  second host     198.18.100.3  third host
```

**macOS** — test first (gone on reboot):

```bash
sudo ifconfig lo0 alias 198.18.100.1 netmask 255.255.255.255
route -n get 198.18.100.1 | grep interface     # must say lo0, not a utun tunnel
nc -z 198.18.100.1 22 && echo ok
# undo: sudo ifconfig lo0 -alias 198.18.100.1
```

Then make it permanent with a launchd job, `/Library/LaunchDaemons/local.lo0-alias.plist`
(validate with `plutil -lint`, install with `sudo install -m 644 -o root -g wheel`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.lo0-alias</string>
  <key>ProgramArguments</key>
  <array>
    <string>/sbin/ifconfig</string><string>lo0</string><string>alias</string>
    <string>198.18.100.1</string><string>netmask</string><string>255.255.255.255</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
</dict>
</plist>
```

```bash
sudo launchctl bootstrap system /Library/LaunchDaemons/local.lo0-alias.plist
launchctl print system/local.lo0-alias | grep -E 'runs|last exit code'   # runs = 1, last exit code = 0
# undo: sudo launchctl bootout system/local.lo0-alias && sudo rm /Library/LaunchDaemons/local.lo0-alias.plist
```

`state = not running` is expected: the job runs `ifconfig` once at boot.

## 4. Gateway network policies — before the route exists

A CIDR route is **organisation-wide**, and the Default profile does not exclude
`198.18.0.0/15`, so every enrolled device would send traffic for your block
into Cloudflare. The shared **Block** policy below is what stops them; create
the policies first.

The design is **one Allow per person** plus **one Block for the whole team
range**, placed under every Allow. Gateway stops at the first match: a person
going to their own block matches their Allow; anybody going to someone else's
block matches no Allow (it names another email) and falls into the Block.

1. **Traffic controls → Traffic settings**: the proxy (*Allow Secure Web
   Gateway to proxy traffic*) must allow **TCP**. Matches on existing network
   policies mean it is already on.
2. **Traffic controls → Firewall policies → Network**: note what is there. An
   organisation often has an *allow all known devices* policy; if yours sit
   below it, it matches first and yours never run.
3. **Add a policy** — *Allow SSH to `<person>` machines*:

   | Section | Selector | Operator | Value |
   | --- | --- | --- | --- |
   | Traffic | Destination IP | in | `198.18.100.0/24` |
   | Traffic (And) | Destination Port | in | `22` |
   | Identity | User Email | in | `you@example.com` |
   | Then | **Allow** | | |

4. **Add a policy, once for the whole team** — *Block SSH tunnel machines for
   everyone else*:

   | Section | Selector | Operator | Value |
   | --- | --- | --- | --- |
   | Traffic | Destination IP | in | `198.18.0.0/16` |
   | Then | **Block** | | |

5. Order: every per-person Allow first, then the shared Block, then every
   pre-existing policy. Nothing else changes for anybody: these only match the
   team range.

Covering a whole `/24` per person means adding a machine later needs no policy
edit; covering a `/16` with the Block means adding a person needs one new
Allow and nothing else.

## 5. The CIDR route

**Networks → Tunnels & Mesh → `my-tunnel` → CIDR routes → Add CIDR route**:
`198.18.100.1/32`, a description, virtual network `default`. Use `/32` per host —
each host's own tunnel carries its own address.

## 6. A device profile for the people who use this

One profile, shared by everyone who follows this page — it only configures
clients; access is decided by the policies of section 4, so being in the
profile grants nothing. If it exists already, add your email to its expression
and skip to the checks at the end of this section.

**Team & Resources → Devices → Device profiles → General profiles → Create new
profile**:

- Name: generic, not a person (for example *SSH via tunnel users*); a
  description saying what it is for.
- Expression: `User email` **in** `you@example.com` — **in**, so the next
  person is one more value in the list.
- **Device tunnel protocol: MASQUE** (confirm the switch from WireGuard). It
  can take a while to reach devices; disconnecting and reconnecting the client
  applies it at once.
- **Lock device client switch: Off** — you need to be able to turn the client
  off to test section 9.
- Service mode *Traffic and DNS*; Split Tunnels *Exclude*; leave the rest.

Then check the profile's **Split tunnels** tab: nothing may cover your block.
The default list (`10.0.0.0/8`, `100.64.0.0/10`, `172.16.0.0/12`,
`192.168.0.0/16`, …) does not. Do **not** remove `100.64.0.0/10` because a
generic guide says so — that advice is for private *hostname* routes and only
when the **Initial resolved IP** range (same page, tab *Initial resolved IP*)
falls inside it. Leave **Local domain fallback** as it is.

On the host, after reconnecting the client:

```bash
warp-cli -j settings | grep '"profile_id"'          # the new profile's ID
warp-cli tunnel dump | grep 198.18 || echo "198.18 not excluded"
```

## 7. Termius on the phone

1. Install **Cloudflare One Agent** from the App Store / Google Play, choose the
   Zero Trust option, enter the team name and log in as `you@example.com`.
   Accept the VPN profile. Turn it **on**.
2. **Termius → Vaults → Keychain → + → Generate Key**: type **ED25519**, a
   passphrase if you want one (*Save passphrase* keeps it behind the phone's
   lock). Open the key and copy the **public** half — one line starting
   `ssh-ed25519 AAAA`. Never copy a line starting `-----BEGIN`.
3. On the host, append it — never replace the file:

   ```bash
   cp -p ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak-$(date +%Y%m%d-%H%M%S) 2>/dev/null
   echo 'ssh-ed25519 AAAA... termius-phone' | ssh-keygen -lf -   # validate first
   echo 'ssh-ed25519 AAAA... termius-phone' >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

4. **Termius → Vaults → Hosts → New Host**: address `198.18.100.1`, port `22`,
   username `you`, password empty, key = the one above. Connect; accept the host
   fingerprint once.
5. Optional: *Startup Command* `herdr` on the host (or a snippet holding it) so
   connecting lands in Herdr. If it says `command not found`, use
   `~/.local/bin/herdr`, or make sure non-interactive shells get that directory
   in `PATH` (`~/.zshenv` on macOS). Detach with `ctrl+b` then `q`.

## 8. Keys only

Once a key login works, stop sshd from accepting passwords. macOS reads
`/etc/ssh/sshd_config.d/*` and the **first** value of each option wins, so the
file must sort before the system's `100-macos.conf`:

```bash
printf '%s\n' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no' 'PermitRootLogin no' \
  | sudo tee /etc/ssh/sshd_config.d/050-keys-only.conf >/dev/null
sudo sshd -t && echo "sshd config OK"
sudo sshd -T | grep -E '^(passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin) '
# undo: sudo rm /etc/ssh/sshd_config.d/050-keys-only.conf
```

No restart: macOS starts sshd per connection. From the host itself,
`ssh -o PubkeyAuthentication=no you@198.18.100.1` must now answer
`Permission denied (publickey)` — `publickey` alone. The host's login password,
`sudo` and the lock screen are unchanged. Losing the phone key means fixing
`authorized_keys` at the keyboard, not being locked out.

## 9. Verify

| Test | Expected |
| --- | --- |
| Termius, Cloudflare One Agent **on** | shell (or Herdr) on the host, no password asked |
| Termius, agent **off** | timeout |
| another user of the organisation, enrolled, to `198.18.100.1:22` | blocked by the shared Block |
| password login over SSH | `Permission denied (publickey)` |
| host rebooted, then **logged in once** | Termius works again |

**FileVault:** after a reboot nothing runs until someone unlocks the disk at the
login screen. A host rebooted while you are away stays unreachable until then.
The host's own Cloudflare One Client does **not** need to be connected for the
phone to get in — inbound traffic arrives through the tunnel.

## 10. More hosts (Windows, Linux) — unverified on host

The policies already cover the `/24`. Per extra host:

1. Its **own tunnel**, installed as a service on that host (`cloudflared.exe
   service install <token>` on Windows; the dashboard shows the Linux command).
   It does not need the Cloudflare One Client: it only receives.
2. A CIDR route for its address (`198.18.100.2/32`, `198.18.100.3/32`, …).
3. That address on the host:
   - **Linux:** `sudo ip addr add 198.18.100.3/32 dev lo`, made persistent with
     your network stack (systemd-networkd, netplan or a oneshot unit).
   - **Windows:** loopback does not take extra addresses directly; install the
     *Microsoft KM-TEST Loopback Adapter* and give it the address. OpenSSH
     Server and the firewall rule are in
     [`12-cloudflare-mesh-and-termius.md`](12-cloudflare-mesh-and-termius.md#3-ssh-servers-on-each-machine).
4. The hub reaches it once its own Cloudflare One Client uses the profile from
   section 6: `Host win` / `HostName 198.18.100.2` in `~/.ssh/config`, then
   `ssh win true` and `herdr --remote win` (see
   [`04-machines-and-ssh.md`](04-machines-and-ssh.md)). Herdr attaching to a
   **native Windows** server over SSH has not been tried; Herdr inside WSL2 is
   the fallback ([`../WINDOWS.md`](../WINDOWS.md)).

## 11. Several people in one organisation

Each person reaches **their own** machines. Nobody gets SSH to someone else's
machine: that would put them in another person's account, with their files and
their full-permission agents.

What is shared and what is per person:

| Piece | Shared or per person | Naming |
| --- | --- | --- |
| Gateway TCP proxy | shared, set once | — |
| Device profile (section 6) | **shared**: one more email per person | generic |
| Block policy on `198.18.0.0/16` | **shared**: one for the team | generic |
| Allow policy | **per person** | with the person's name, so it is obvious whose it is and what to delete when they leave |
| Address block (`/24`) | **per person**, unique in the organisation | — |
| Tunnel, loopback address, CIDR route | per machine | the machine or the person |
| Termius key, `authorized_keys`, keys-only sshd | per person, on their own devices | — |

**Keep a register of blocks.** CIDR routes share the organisation's `default`
virtual network: two people on the same address collide. Hand out one `/24`
each — `198.18.100.0/24`, `198.18.101.0/24`, … — and write down who has which
in a place the team can read but that is **not** this public repository (an
internal wiki, the admin's notes). The CIDR route descriptions in the
dashboard are a second copy.

### Onboarding the next person

The admin, in the dashboard:

1. Pick a free block from the register, for example `198.18.101.0/24`, and
   record it.
2. Add their email to the shared device profile's expression.
3. Add their **Allow** policy (section 4, step 3, with their block and their
   email) and drag it **above** the shared Block. Below it, the Block hides it
   and they cannot get in.

The person, on their machine and phone (sections 1, 3, 5, 7, 8):

4. A tunnel on their machine (or reuse their own).
5. Their loopback address (`198.18.101.1`) and its CIDR route (`198.18.101.1/32`).
6. Cloudflare One Agent enrolled and reconnected (so the profile applies),
   their Termius key in their own `authorized_keys`, keys-only sshd.
7. The checks of section 9 — including that **they cannot** reach anybody
   else's block, and nobody else can reach theirs.

Never add someone's email to another person's Allow policy.

### Offboarding

Delete their Allow policy, remove their email from the profile, revoke their
devices in Zero Trust, delete their CIDR routes (and their tunnel if it was only
for this), and free the block in the register. The shared Block keeps
covering the range in the meantime.

## When it does not connect

Change one layer at a time: Termius → agent on? → policy → route → tunnel →
loopback address → sshd → `authorized_keys`.

| Symptom | Check |
| --- | --- |
| Termius times out | phone agent connected and on the shared profile? your Allow **above** the shared Block, both above the organisation's own policies? CIDR route saved on the right tunnel? `route -n get 198.18.100.1` on the host says `lo0`? |
| Termius asks for a password and fails | expected after section 8 when no key is selected on the host entry |
| a hostname route answers `REFUSED` | the DNS loop of section 2; use a CIDR route |
| tunnel logs show `already connected to this server` | two `cloudflared` processes run the same tunnel (a system daemon and a user agent); keep one |
| `Permission denied (publickey)` with the right key | the key line in `authorized_keys` is wrapped or edited; re-add it in one line |
| works until reboot | the launchd job (`launchctl print system/local.lo0-alias`), and FileVault unlocked? |

## Security checklist

- Every route sits inside the team range covered by the shared Block, with
  exactly one Allow above it naming its owner. A CIDR route outside that range
  is reachable by everyone in the organisation.
- A person on the **same LAN** can still reach sshd on the host's LAN address
  without Cloudflare. Keys-only sshd makes that useless; restricting port 22
  with the host firewall (`pf` on macOS) closes it too — see
  [page 12, section 7](12-cloudflare-mesh-and-termius.md#7-close-the-lan-bypass-only-after-section-6-passes),
  `unverified on host`.
- sshd is key-only; Cloudflare is a gate in front of it, not a replacement.
- One key per device and trust domain; private keys never leave the device
  that generated them. Remove old clients' keys from `authorized_keys` (and
  their firewall exceptions) when you stop using them.
- The agents run this kit's **full-permission** wrappers: whoever reaches sshd
  controls them.
- A lost phone: revoke the device in Zero Trust **and** delete its key line.

## For an agent guiding this setup

- Inspect before asking: `warp-cli status`, `warp-cli registration organization`,
  `warp-cli tunnel dump`, `warp-cli -j settings`, `nc -z`, `route -n get`,
  `launchctl print`, `sshd -T` are read-only. Mask tokens in `ps` output.
- The human runs every `sudo` command in their own terminal: an agent's shell
  (and Claude Code's `!` prefix) cannot answer the password prompt.
- Dashboard steps are confirmed from the human's screenshots, one screen at a
  time, **before** they press Save. Check selector names: a policy row left on
  *SNI* with an IP value silently never matches.
- Names and descriptions typed into the dashboard are suggested in English.
- Never edit the Default device profile. New Allow policies go above the
  shared Block; never move the organisation's own policies above either.
- Onboarding someone is section 11's checklist; check the block register
  before choosing an address. Never print the tunnel token, key
  material or the person's identity into the repository.

## Appendix: Method A — public hostname (laptops only)

On the tunnel, add a **published application route** for a public hostname such
as `ssh.example.com`, service *SSH* `localhost:22`, and a **self-hosted Access
application** for that hostname — without it, anyone who finds the name reaches
your sshd. On each laptop install `cloudflared` and add:

```sshconfig
Host devbox
  HostName ssh.example.com
  User dev
  ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
```

(Use the path `command -v cloudflared` prints.) The first `ssh devbox` opens a
browser login; Herdr's remote attach uses your SSH config, so the
`ProxyCommand` applies. A saved machine cannot answer that browser login: when
the Access token expires it shows *Attention* until you run `ssh devbox true`
in a terminal. This method is `unverified on host`.

## Tailscale or Cloudflare?

| | Tailscale ([page 10](10-tailscale-and-termius.md)) | Cloudflare Tunnel (this page) |
| --- | --- | --- |
| Setup | an app on every device | a tunnel per host + two policies + a profile + the app on clients |
| Termius | direct | through the Cloudflare One Agent (method B) |
| Identity | your tailnet login | your Zero Trust identity, per policy |
| Already use Cloudflare Zero Trust | — | fits naturally |
