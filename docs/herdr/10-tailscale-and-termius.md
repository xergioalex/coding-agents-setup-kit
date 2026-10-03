# 10. Herdr from anywhere: Tailscale + Termius

Goal: your agents run in Herdr on a **host** (a Linux box, a VM, a container, a
WSL distro), and you check on them, answer a `blocked` prompt or start new work
from a **laptop or phone**, over a private network, with no port opened to the
internet.

```
phone (Termius) ─┐                       ┌─ host: sshd + herdr server + agents
                 ├── tailnet (WireGuard) ─┤
laptop (ssh,     ┘   100.x.y.z / MagicDNS └─ (Linux, VM, container, WSL)
 herdr --remote)
```

**Run Herdr where the work lives; attach from wherever you are.** The Herdr
server and the agents stay on the host; the phone only renders a terminal.
Closing Termius or losing signal never kills an agent.

Sources: <https://herdr.dev/docs/how-to-work/> ·
<https://tailscale.com/kb/1193/tailscale-ssh> ·
<https://tailscale.com/kb/1081/magicdns> ·
<https://docs.termius.com/organize-and-connect-to-hosts/connecting-to-a-server>
(read 2026-10-03). The end-to-end flow below is **unverified on host** as a
whole: each piece follows its vendor's documentation.

## 1. Host: Herdr + SSH

```bash
curl -fsSL https://herdr.dev/install.sh | sh     # or ./install.sh --onboard from this kit
herdr --version && herdr status
ssh localhost true                                # sshd must already work locally
```

A Docker container as the host: follow
[`05-container-setup.md`](05-container-setup.md) first.

## 2. Network: put host and clients on one tailnet

Install Tailscale on the host, the laptop and the phone (App Store / Google
Play), and sign in to the **same** tailnet on all of them. Then pick how SSH is
authenticated:

| Option | On the host | Works when the host is | Keys |
| --- | --- | --- | --- |
| **A. Plain OpenSSH over the tailnet** | nothing extra: sshd already listens; Tailscale just routes | any OS with an SSH server (Linux, macOS, Windows OpenSSH Server, a container) | your normal SSH keys |
| **B. Tailscale SSH** | `tailscale set --ssh` | **Linux** (and the open-source macOS variant) — **not Windows** | none: identity comes from the tailnet, enforced by the `ssh` rules in your tailnet policy |

Option B needs an `ssh` rule in the tailnet policy file, for example letting
your own user reach your own devices as a non-root account:

```json
"ssh": [
  { "action": "check", "src": ["autogroup:member"], "dst": ["autogroup:self"], "users": ["autogroup:nonroot"] }
]
```

`check` re-asks for identity periodically; `accept` does not. Tailscale SSH only
claims port 22 on the **Tailscale** address; sshd on other interfaces is
untouched.

**Names.** With MagicDNS (on by default for tailnets created since October 2022)
the host is reachable as `devbox` or `devbox.<tailnet>.ts.net`. Use the name, not
the `100.x` address, so nothing breaks if the address changes.

## 3. Laptop: saved machine or remote attach

Add an SSH alias that points at the tailnet name (keep the rules in
[`04-machines-and-ssh.md`](04-machines-and-ssh.md): no
`UserKnownHostsFile /dev/null`):

```sshconfig
Host devbox
  HostName devbox.example.ts.net     # your MagicDNS name
  User dev
  ServerAliveInterval 30
```

```bash
ssh devbox true                                # must succeed non-interactively first
herdr machine add devbox --label "Dev box"     # Local + Dev box in one window
# or, for a single remote session with your local UI:
herdr --remote devbox
```

Agents on your laptop can now drive agents on the host with
`herdr --machine "Dev box" …` — see [`09-agent-to-agent.md`](09-agent-to-agent.md).

## 4. Phone: Termius

1. **Keychain → Key**: generate a key in Termius (or import one) and add its
   public half to `~/.ssh/authorized_keys` on the host. With Tailscale SSH
   (option B) no key is needed.
2. **New Host**: Alias `devbox`, Hostname `devbox.example.ts.net` (or just
   `devbox`), Port `22`, Username `dev`, Key = the key above.
3. **Startup Command**: create a snippet `herdr` (or
   `herdr --session agents` for a named session) and select it in
   *Host Details → Startup Command*; it runs every time you connect, so opening
   the host lands you straight in Herdr.
4. Optional **Use Mosh**: survives network switches and sleep better than SSH.
   It needs `mosh-server` installed on the host and its UDP ports reachable over
   the tailnet. Herdr over Mosh is `unverified on host`.

Using Herdr on a phone:

- The interface adapts to narrow screens; zoom a pane to read it full-width.
- Detach with the prefix then `q` (`ctrl+b`, then `q`, by default) — the agents
  keep running. Use the Ctrl key on Termius's extra keyboard row.
- To answer a `blocked` agent: focus its pane and type, exactly as on a laptop.

## Security checklist

- No port forwarded on your router; nothing listens on a public address.
- Prefer key auth (option A) or Tailscale SSH with `check` (option B); never
  password auth on the host.
- Restrict who can reach the host with tailnet policy (`grants` / `ssh` rules),
  not just with sshd.
- The agents run with this kit's **full-permission** wrappers: anyone who can
  reach that SSH session controls them. Treat tailnet membership as that level of
  access.
- Remove a lost phone from the tailnet admin console and revoke its SSH key.

## When it does not connect

| Symptom | Check |
| --- | --- |
| `ssh devbox` hangs | `tailscale status` on both ends; is the phone/laptop connected to the tailnet? |
| name does not resolve | MagicDNS enabled? Try the full `devbox.<tailnet>.ts.net` or the `100.x` address |
| `Permission denied` with Tailscale SSH | the `ssh` rule's `users` list and `dst` must match the account and device |
| saved machine stuck in *Attention* | run the command Herdr prints (usually `herdr --remote devbox`) in a real terminal once — host key, passphrase or install prompt |
| Windows host refuses Tailscale SSH | expected: use option A with the Windows OpenSSH Server |
