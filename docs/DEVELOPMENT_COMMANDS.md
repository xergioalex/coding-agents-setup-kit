# Development commands

Everything here is verbatim and runs from the repository root. There is no
package manager, no build step and no type-check: this repo is bash, PowerShell
and stdlib Python.

## Validate

```bash
tests/run.sh                  # the gate — expect "passed: N  failed: 0"
tests/run.sh lint             # static checks only
tests/run.sh writers          # the three config writers
tests/run.sh machines         # agentbox
tests/run.sh win              # the Windows layer (static)
```

```bash
shellcheck -S warning install.sh lib/*.sh bin/* tests/run.sh   # brew/apt install shellcheck
bash -n <script>                                               # syntax only
python3 -m py_compile lib/*.py
```

With PowerShell available (any OS):

```bash
pwsh -NoProfile -Command "Get-ChildItem win -Recurse -Include *.ps1,*.psm1 | % { \$e=\$null; [void][System.Management.Automation.Language.Parser]::ParseFile(\$_.FullName,[ref]\$null,[ref]\$e); if(\$e){ \$_.FullName } }"
```

## Try without installing

Every wrapper runs straight from the checkout:

```bash
bash bin/agentkit status
bash bin/claudex --help
AGENTKIT_MACHINES=./machines.example.toml bash bin/agentbox ls
AGENTKIT_MACHINES=./machines.example.toml bash bin/agentbox ssh-config
```

To exercise the installer without touching your real home directory:

```bash
HOME=/tmp/kit-sandbox AGENTKIT_ENV=/tmp/kit-sandbox/env \
  AGENTKIT_HOME=/tmp/kit-sandbox/kit bash install.sh --no-path
```

## Install (this is a human decision)

```bash
./install.sh                 # wrappers + PATH + env skeleton
./install.sh --onboard       # + detect and install missing CLIs
./install.sh --clis          # CLIs only
./install.sh --no-path       # do not touch your shell rc
```

```powershell
.\install.ps1 -Onboard       # Windows
```

## Doctor

```bash
agentkit status              # or: bash bin/agentkit status
agentkit onboard             # report; --clis also installs missing CLIs
agentkit path && agentkit env-path && agentkit machines-path
```

## Machines

```bash
agentbox ls
agentbox status [name]
agentbox up|stop|down|restart <name> [--no-herdr]
agentbox ssh <name> [-- <command>]
agentbox herdr [<name>] [status|add|enable|disable|remove]
agentbox ssh-config [--write]
agentbox doctor
```

## Herdr (the official client, not wrapped by this kit)

```bash
herdr --version && herdr status
herdr machine list --json
herdr integration status
```
