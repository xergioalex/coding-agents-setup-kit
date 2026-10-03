# 11. Herdr from anywhere: Cloudflare Tunnel + Termius

The same goal as [`10-tailscale-and-termius.md`](10-tailscale-and-termius.md) —
agents run in Herdr on a host, you attach from a laptop or phone — but the path
is a **Cloudflare Tunnel**: the host makes an outbound connection to Cloudflare,
so it needs no public IP and no open inbound port, and access is gated by
Cloudflare Zero Trust (Access) policies.

Sources: <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/>
and its child pages, and
<https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/download/>
(read 2026-10-03). The end-to-end flow is **unverified on host**; dashboard menu
names change, so follow the linked page when they differ.

## Pick the method by client

Cloudflare documents four ways to SSH through a tunnel. What matters here is
**which ones Termius can use**:

| Method | Client needs | Laptop terminal / `herdr --remote` | Termius (phone) |
| --- | --- | --- | --- |
| **A. Public hostname + `cloudflared` on the client** | `cloudflared` and a `ProxyCommand` in `~/.ssh/config` | yes | **no** — a phone SSH app cannot run `cloudflared` as a `ProxyCommand` |
| **B. Private network + Cloudflare One Client (WARP)** | the *Cloudflare One Agent* app, enrolled in your Zero Trust org | yes | **yes** — Termius connects to a private hostname/IP as if on a LAN |
| C. Access for Infrastructure | Cloudflare One Client + short-lived SSH certificates | yes | `unverified on host` — needs the client plus certificate-based login in Termius |
| D. Browser-rendered SSH | a web browser | no (not a terminal Herdr can use) | no (a browser, not Termius) |

**Recommendation:** method **B** if you want Termius; method **A** is the
quickest for laptops only. You can run both on one tunnel.

## 1. Host: Herdr + SSH + the tunnel

```bash
curl -fsSL https://herdr.dev/install.sh | sh     # or ./install.sh --onboard from this kit
ssh localhost true                                # sshd must already work locally
```

Then in the Cloudflare dashboard: **Networking → Tunnels → Create a tunnel**,
name it, and run the `cloudflared` install command the dashboard shows on the
host. The tunnel then needs a **route** — which kind depends on the method.

## Method A — public hostname (laptops)

On the tunnel, add a route for a public hostname such as `ssh.example.com` with
**Service** = *SSH*, `localhost:22`. Then add a **self-hosted Access
application** for `ssh.example.com` so only your identity can reach it — without
that policy, anyone who finds the name reaches your sshd.

On each laptop, install `cloudflared` and add:

```sshconfig
Host devbox
  HostName ssh.example.com
  User dev
  ProxyCommand /usr/local/bin/cloudflared access ssh --hostname %h
```

(Use the path `command -v cloudflared` prints, or `cloudflared.exe` on
Windows.) The first `ssh devbox` opens a browser to log in to your identity
provider. After that:

```bash
ssh devbox true
herdr --remote devbox                          # or: herdr machine add devbox --label "Dev box"
```

Herdr's remote attach includes your own SSH config, so the `ProxyCommand` is
used. A saved machine connects in the background and **cannot** answer a browser
login: if the Access token has expired the machine shows *Attention*; run
`ssh devbox true` in a terminal to log in again.

## Method B — private network + Cloudflare One Agent (Termius)

1. On the tunnel, add a **private** route: a private hostname (recommended, for
   example `devbox.internal`) or a CIDR route that includes the host's private
   IP.
2. In Zero Trust, configure **Split Tunnels** so those addresses go through the
   client. Cloudflare's guide for hostname routes also lists `172.64.128.0/20` and
   `2606:4700:0cf1:4000::/64`, and asks you to remove the private TLD from
   *Local Domain Fallback*.
3. Add a **Gateway network policy** that allows your identity to reach the
   host on TCP 22, and blocks everyone else.
4. On the phone, install **Cloudflare One Agent** (App Store / Google Play) and
   enroll it in your Zero Trust organisation. Do the same on laptops with the
   Cloudflare One Client if you want them on this path too.

Then in **Termius**:

1. **Keychain → Key**: generate or import a key; put its public half in
   `~/.ssh/authorized_keys` on the host.
2. **New Host**: Hostname `devbox.internal` (or the private IP), Port `22`,
   Username `dev`, Key = the key above.
3. **Startup Command**: a snippet `herdr` (or `herdr --session agents`) selected
   in *Host Details → Startup Command*, so connecting lands you in Herdr.
4. Connect with the Cloudflare One Agent switched **on**.

Detach with `ctrl+b` then `q`; the agents keep running on the host.

## Security checklist

- Every route is behind an Access application (method A) or a Gateway policy
  (method B). A tunnel without a policy is a public SSH endpoint.
- Keep sshd key-only; Access is a second gate, not a replacement.
- The agents run with this kit's **full-permission** wrappers: whoever passes
  the policy controls them. Scope the policy to your own identity.
- A lost phone: revoke its device in Zero Trust and remove its SSH key.

## Tailscale or Cloudflare?

| | Tailscale ([page 10](10-tailscale-and-termius.md)) | Cloudflare Tunnel (this page) |
| --- | --- | --- |
| Setup | an app on every device | a tunnel + Zero Trust policies + an app for Termius |
| Termius | direct, any method | only with the Cloudflare One Agent (method B or C) |
| Laptop without an extra app | no | yes, with `cloudflared` (method A) |
| Identity | your tailnet login (+ Tailscale SSH) | your identity provider through Access |
| Already use Cloudflare for your domains | — | fits naturally |

## When it does not connect

| Symptom | Check |
| --- | --- |
| `ssh devbox` prints a Cloudflare login URL every time | normal when the Access session expires; log in, then retry |
| method A fails before any login prompt | the route must be type *SSH* to `localhost:22` on the host, and the Access application must cover that exact hostname |
| Termius times out (method B) | Cloudflare One Agent connected? Split Tunnels include the host's route? Gateway policy allows TCP 22? |
| saved machine stuck in *Attention* (method A) | the background connection cannot do the browser login; run `ssh devbox true` once in a terminal |
