# 8. Troubleshooting

Always start here:

```bash
herdr -V && herdr status
ls ~/.config/herdr/            # herdr.log, herdr-client.log, herdr-server.log
HERDR_LOG=herdr=debug herdr    # more detail while you reproduce it
```

| Symptom | Cause | Fix |
| --- | --- | --- |
| `herdr: command not found` | the install directory is not on PATH in this shell | open a new terminal; `~/.local/bin` is in this kit's PATH block; package-manager installs land elsewhere |
| Updated, but the session behaves like the old version | a compatible old **server** is still running, by design | `herdr` again for client changes; for server features `herdr server stop && herdr` (this ends pane processes — ask first) or `herdr update --handoff` |
| Agent shows `unknown` or the wrong state | manifest mismatch, or a wrapper/VM hiding the process | `herdr agent explain <target> --json`; `herdr server update-agent-manifests`; `HERDR_AGENT=<kind>` on the wrapper; install the integration |
| A keybinding does nothing | the OS or the outer terminal consumed the chord | pick another binding, or free the chord in your terminal |
| Keys fire twice | an old terminal emulator | update the outer terminal |
| Remote attach cannot authenticate | plain SSH fails, or a passphrase prompt cannot be shown | make `ssh <alias>` work first; `ssh-add`; then `herdr --remote <alias>` |
| Saved machine stuck in **Attention** | host key, MFA, an install or an incompatible server needs a foreground answer | run the command Herdr prints (usually `herdr --remote <target>`), then restart the client |
| Machine shows `reconnecting` | **almost always the box is down**, not a Herdr bug | `agentbox status <name>`, then `agentbox up <name>` |
| Machine never enables, and nothing else is wrong | its `target` does not match your SSH alias | `agentbox doctor`; a target cannot be renamed — remove and re-add |
| `ssh <alias>` says `Connection closed` although the container is healthy | something else owns that loopback port (often an IDE's remote-containers forwarder) | find the owner (`lsof -nP -iTCP:<port> -sTCP:LISTEN` / `Get-NetTCPConnection`) and close it |
| `machine add` fails with "server closed connection; machine was not saved" | a race between the client and a just-started SSH server | make sure `ssh -o BatchMode=yes <alias> true` succeeds, then retry; if it persists, check the Herdr issue tracker for your version |
| Panes open in `$HOME` instead of the project | `[terminal] new_cwd` unset — or the config has two `[terminal]` tables and is invalid TOML, so the whole file is ignored | validate the file with a TOML parser, then fix `new_cwd` |
| Keychain- or credential-backed tools fail inside panes | the server was started from a background or SSH context without that session's credentials | stop that server and start `herdr` from a normal desktop terminal |

If none of this matches, the log files above plus `herdr status --json` are what
an issue report needs. Official troubleshooting page:
<https://herdr.dev/docs/>
