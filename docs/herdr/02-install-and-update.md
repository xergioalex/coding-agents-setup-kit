# 2. Install and update

## Install

Pick one method and stay with it; mixing them is how you end up with two
binaries and a confusing `herdr status`.

| Method | Command | Updates with |
| --- | --- | --- |
| Official installer (binary in `~/.local/bin`) | `curl -fsSL https://herdr.dev/install.sh \| sh` | `herdr update` |
| Homebrew (macOS/Linux) | `brew install herdr` | `brew upgrade herdr` — `herdr update` is disabled |
| mise | `mise use -g herdr` | mise |
| Nix | `nix profile install github:herdrdev/herdr/<tag>` | `nix profile upgrade …` |
| Manual | download the asset for your platform from <https://github.com/herdrdev/herdr/releases>, make it executable, put it on PATH | manual |

`./install.sh --clis` in this kit uses the first method when `herdr` is missing.

**Windows:** check <https://herdr.dev/docs/install/> for the current platform
list before assuming. If there is no native Windows build, run Herdr inside WSL2
or on a remote host — see [`../WINDOWS.md`](../WINDOWS.md).

`~/.local/bin` must be on PATH; this kit's PATH block includes it.

## Verify

```bash
herdr --version          # e.g. herdr 0.9.x
herdr status             # client + server versions, protocol, socket, update flags
herdr                    # first launch shows an onboarding flow; detach with ctrl+b q
```

`~/.config/herdr/config.toml` is optional. `herdr --default-config` prints every
default. Logs live next to it: `herdr.log`, `herdr-client.log`,
`herdr-server.log` (named sessions get their own subdirectory).

## Update

```bash
herdr update                 # direct installs only; keeps compatible running servers alive
herdr update --handoff       # experimental: hand panes to the new server without losing processes
herdr channel show | set stable | set preview
```

Rules worth knowing before you update someone's running work:

- Updating the **binary** does not replace a compatible **running server**. Start
  `herdr` again to use the new client; server-side features wait until that
  server is stopped and restarted. `herdr server stop` ends its pane
  processes — ask the human first.
- A version difference alone never stops a remote server; replacing one asks
  first, and the default answer is No.
- With a package manager install, update through the package manager.

## Shell completions

```bash
mkdir -p ~/.zfunc && herdr completion zsh > ~/.zfunc/_herdr
# in ~/.zshrc:  fpath=(~/.zfunc $fpath); autoload -Uz compinit; compinit
```

`herdr completion bash` and `fish` exist too — check `herdr completion --help`.

## The Herdr agent skill (optional)

Herdr ships a skill that teaches a coding agent to drive Herdr from inside a
pane. `herdr --skill` prints it locally. Installing it writes into that agent's
config, so **ask the human first**.

Official pages: <https://herdr.dev/docs/install/> · <https://herdr.dev/docs/agent-skill/>
