# 5. Making a Docker container Herdr-ready

Goal: a container your Herdr client can attach to as a saved machine. Herdr needs
only **SSH plus a compatible `herdr` binary on the remote PATH**. It can install
one with your approval, but an image that ships it never makes a background
reconnect wait on a prompt.

Adapt the user names and ports; nothing here is specific to any project.

## 1. Dockerfile

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
      openssh-server curl ca-certificates \
 && mkdir -p /var/run/sshd \
 && ssh-keygen -A                       # host keys — without them sshd accepts the TCP connection and closes it

# A drop-in only. Do NOT redefine "Subsystem sftp": it is already in the distro's
# sshd_config, and a duplicate makes `sshd -t` fail, which means no SSH at all.
RUN printf '%s\n' 'PasswordAuthentication no' 'PubkeyAuthentication yes' \
      'PermitRootLogin no' 'AllowUsers dev' \
      'ClientAliveInterval 30' 'ClientAliveCountMax 6' \
    > /etc/ssh/sshd_config.d/herdr.conf && chmod 644 /etc/ssh/sshd_config.d/herdr.conf

USER dev
RUN curl -fsSL https://herdr.dev/install.sh | sh \
 && mkdir -p ~/.config/herdr \
 && printf '%s\n' '[experimental]' 'allow_nested = true' > ~/.config/herdr/config.toml \
 && ~/.local/bin/herdr --version
# Herdr panes are non-login shells that source ~/.bashrc
RUN printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> ~/.bashrc
```

`allow_nested = true` lets `herdr --remote` be launched from inside a pane that
is itself inside Herdr — needed when an agent in the container attaches onward.

**Also set `[terminal] new_cwd`, or every pane opens in `$HOME`.** Herdr starts
new panes, tabs and workspaces in the home directory unless told otherwise, so a
fresh console lands nowhere useful and has to be `cd`'d by hand every time.

Two traps, both of which look like "Herdr ignored my config":

- A config file with **two `[terminal]` tables** is invalid TOML. Herdr then
  ignores the **whole** file — taking `allow_nested` with it — while a `grep` for
  `new_cwd` still shows your line. Validate it:
  `python3 -c "import tomllib,sys;tomllib.load(open(sys.argv[1],'rb'))" ~/.config/herdr/config.toml`
- The config usually lives in a **persisted volume**, so a container whose volume
  predates the setting never picks it up from an image build. Do the edit in the
  **entrypoint** as well.

## 2. docker-compose

```yaml
services:
  devbox:
    ports:
      - '${HERDR_SSH_HOST_PORT:-22029}:22'   # pick a free host port and check it first
    volumes:
      - herdr_data:/home/dev/.config/herdr   # keep Herdr config and state across rebuilds
      - ~/.ssh/id_ed25519.pub:/run/host-keys/id_ed25519.pub:ro
volumes:
  herdr_data: {}
```

Publish on the loopback only (`'127.0.0.1:22029:22'`) if you do not want the port
reachable from your network. Check what already listens before choosing:

```bash
lsof -nP -iTCP:22029 -sTCP:LISTEN                 # macOS / Linux
Get-NetTCPConnection -LocalPort 22029 -State Listen   # Windows
```

On macOS avoid `2222` — the Cursor desktop app owns it.

## 3. Entrypoint (runs as root, then drops to the user)

```bash
# authorized_keys from the mounted public keys, idempotently
mkdir -p /home/dev/.ssh && touch /home/dev/.ssh/authorized_keys
for pub in /run/host-keys/*.pub; do
  [ -f "$pub" ] && ! grep -Fqx -f "$pub" /home/dev/.ssh/authorized_keys && { cat "$pub"; echo; } >> /home/dev/.ssh/authorized_keys
done
chown -R dev:dev /home/dev/.ssh
chmod 700 /home/dev/.ssh && chmod 600 /home/dev/.ssh/authorized_keys

# repair a config volume created before these settings existed
grep -q '^allow_nested' /home/dev/.config/herdr/config.toml 2>/dev/null \
  || printf '\n[experimental]\nallow_nested = true\n' >> /home/dev/.config/herdr/config.toml

mkdir -p /var/run/sshd && /usr/sbin/sshd -t && /usr/sbin/sshd
```

A change to an entrypoint needs a **rebuild** — it is `COPY`ed into the image, so
`down` and `up` alone recreate the container from the old one.

## 4. Verify from your machine

```bash
docker compose up -d devbox
docker exec devbox sh -c 'ps aux | grep [s]shd; ls /etc/ssh/ssh_host_*'
ssh-keyscan -p 22029 127.0.0.1 >> ~/.ssh/known_hosts
ssh -o BatchMode=yes -p 22029 dev@127.0.0.1 'echo OK && herdr --version && herdr status server --json'
```

`status server --json` should list capabilities including `surface_interest` and
`health_check`, which saved-machine connections require. Then add the machine
([`04-machines-and-ssh.md`](04-machines-and-ssh.md)), or let
`agentbox herdr <name> add` do it.

## 5. The agents inside the container

A Herdr pane in the container is a `bash` shell sourcing `~/.bashrc`. To get the
same wrappers as on your own machine, install this kit in the image:

```dockerfile
USER dev
RUN git clone --depth 1 https://github.com/xergioalex/coding-agents-setup-kit.git /tmp/kit \
 && cd /tmp/kit && ./install.sh --no-path \
 && printf '\nexport PATH="$HOME/.local/share/coding-agents-kit/bin:$PATH"\n' >> ~/.bashrc
```

Mount or inject the env file at runtime — never bake keys into an image.

## Gotchas collected the hard way

- Missing host keys → SSH accepts the connection and immediately closes it.
- A drop-in that repeats `Subsystem sftp` → `sshd -t` fails → no SSH.
- `UserKnownHostsFile /dev/null` on the client side → permanent Attention.
- `localhost` in the alias → IPv6 `::1` → some other listener answers.
- An old config volume that predates `allow_nested` → patch it in the entrypoint.
- Panes opening in `$HOME` → `new_cwd` unset, **or** the config has two
  `[terminal]` tables and Herdr silently ignored the whole file.
- An IDE's remote-containers extension can open its own forwarder on
  `127.0.0.1:<port>` while it is attached, and that listener wins over Docker's:
  `ssh <alias>` then fails with `Connection closed` while the container is fine.
  Check what owns the port before changing anything in the container.
