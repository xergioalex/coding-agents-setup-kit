# Agent bootstrap prompt

Hand this whole file to a coding agent on the machine you want set up. It works
on a fresh machine and on one that already has some of these tools. It is the
only instruction the agent needs.

---

You are installing **coding-agents-setup-kit** on this machine.

Clone <https://github.com/xergioalex/coding-agents-setup-kit> (or use the folder
you were given) and work from the directory that contains `install.sh`.

**Rules for this job:**

- Never print, log or commit an API key. Never ask the human to paste one into
  the chat.
- Never reinstall, uninstall, move or re-link a CLI that is already there.
- Never invent an install command. If a vendor URL fails, look up that product's
  current official install page and use that; if there is no documented path for
  this OS, say so and move on.

**Steps:**

1. Identify the OS. macOS, Linux and WSL use `./install.sh`; native Windows
   PowerShell uses `.\install.ps1`. If you are in a WSL shell, say so — WSL and
   Windows are two machines that share a disk, and installing in one does
   nothing for the other.
2. On macOS/Linux: `chmod +x install.sh bin/* lib/*.sh`
3. Run the onboarding installer:
   - macOS / Linux / WSL: `./install.sh --onboard`
   - Windows: `.\install.ps1 -Onboard`
   It prints **Before** (what is already installed) and an **Onboard plan**
   (what it will skip versus install). It refreshes the wrappers, creates the
   env file **only if missing**, and installs **only missing** CLIs.
4. Note that an `agent` command on PATH may be the xAI Grok CLI, not Cursor. The
   kit resolves Cursor itself — trust its output, not `command -v agent`.
5. Put the kit on PATH for this shell:
   - macOS / Linux: `export PATH="$HOME/.local/share/coding-agents-kit/bin:$HOME/.local/bin:$PATH"`
   - Windows: open a new terminal (the installer edited the user `Path`).
6. Run `agentkit status` and report to the human:
   - which CLIs were already there (kept),
   - which were newly installed, and which are still missing and why,
   - which wrappers are on PATH,
   - which env keys are **set** versus **unset** — by name, never by value.
7. If keys are unset, tell the human to edit the env file themselves
   (`agentkit env-path` prints the location). `grokx` works with `grok login`
   and no key at all.
8. If they want Herdr, point them at `docs/herdr/`. Do not add, remove or enable
   a Herdr machine, and do not install a Herdr integration — both edit things
   that are theirs. Report what you would do and let them decide.
9. Stop. Do not start a long agent session unless they ask.

**Reference while working:** `INSTALL.md`, `docs/coding-agents/README.md`,
`docs/herdr/README.md`, `docs/WINDOWS.md`. To work *on the kit itself* instead,
read `AGENTS.md`.

**Known on purpose:** there is no `claude-azure` or `claudex-xai` (no
Anthropic-compatible endpoint exists for those providers). The GLM wrapper for
Claude Code is `claude-glm`, with `claudex-glm` as an alias. `cursorx` runs
Cursor with `--force` and never falls back to Grok.
