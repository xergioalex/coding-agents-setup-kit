# Standards

## Language and tooling

- **English everywhere**: scripts, comments, docs, commit messages.
- **Bash**: `#!/usr/bin/env bash`, `set -euo pipefail`, two-space indent, `[[ ]]`
  tests, quoted expansions, `local` in functions, no `eval`.
  `shellcheck -S warning` must be clean (`tests/run.sh lint`).
- **Python** (`lib/*.py`): stdlib only, 3.8+ compatible, a module docstring that
  states the usage line and the safety rules, `sys.exit(2)` on bad usage,
  `sys.exit(1)` on a refusal with an `agentkit:` / `agentbox:` prefixed message
  on stderr.
- **PowerShell** (`win/lib/*.ps1`, `*.psm1`): `Set-StrictMode -Version Latest`,
  approved verbs for exported functions, `[Console]::Error.WriteLine` for the
  error contract, `exit $LASTEXITCODE` after invoking a CLI. `.cmd` shims stay
  **CRLF and ASCII-only**; every other script stays **LF**. `.ps1`/`.psm1` files
  are **ASCII-only** too: Windows PowerShell 5.1 reads a BOM-less file as ANSI,
  and the last byte of a UTF-8 em dash (`0x94`) becomes a closing quote that
  breaks the parse. Write `-`, not `—`. The gate checks all three. Variable
  names are case-insensitive: never assign a script-scope `$rest` in a file
  whose parameter is `$Rest` (it *is* the parameter); use `$argv_`.
- **Markdown**: no YAML frontmatter (this is evergreen reference), tables for
  reference material, fenced blocks with a language.

## Naming

- Wrappers: `<cli>x` for the default-provider full-permission launcher
  (`claudex`, `codexx`, `pix`, `clinex`); `<cli>-<provider>` for provider
  variants (`codex-azure`, `opencode-glm`). `claudex-glm` and `clinex-azure`
  exist as aliases of `claude-glm` and `cline-azure` because people type the
  `<cli>x` form by habit.
- Env variables: `ZAI_*`, `XAI_*`, `AZURE_OPENAI_*` for providers; `AGENTKIT_*`
  for the kit itself; each CLI's own variable where one exists (`CODEX_HOME`,
  `OPENCODE_CONFIG`, `PI_MODELS_FILE`).
- Shell functions in `lib/`: `agentkit_<verb>_<noun>`.
- Provider ids on disk: Codex `azure|xai|glm`; OpenCode `azure|xai|zai-coding-plan`;
  Pi `azure-foundry|xai-grok|zai-glm`.

## Session-flag contract (every wrapper, every OS)

| Flag | Meaning |
| --- | --- |
| `-c`, `--continue` | continue the most recent session |
| `-r`, `--resume [id]` | resume by id, or open the CLI's picker |
| `-l` | Codex: `resume --last`; Cursor: `ls` |
| anything else | passed through verbatim, after the kit's own flags |

Keep this table true when you add a wrapper — on **both** sides (`bin/` and
`win/lib/Invoke-Wrapper.ps1`). The gate asserts that every wrapper exists on
both, but only a human can tell whether the mapping still means the same thing.

## Secrets and config writing (hard rules)

1. Never print, log, echo or trace a variable ending in `_API_KEY`, `_TOKEN`,
   `_SECRET`. The doctor reports keys as `set` / `unset`.
2. Never write a secret value into a file. Codex → `env_key`; OpenCode →
   `{env:KEY}`; Pi → `"$KEY"`. Cline is the one documented exception (argv).
3. Never overwrite a user-owned config wholesale: merge the block you own, keep
   everything else, refuse on parse failure, write atomically, keep a one-time
   `.agentkit.bak`.
4. Never overwrite the user's env file.
5. Never run a package manager's global-bin bootstrap (`pnpm setup`) and never
   edit a shell rc beyond the single guarded PATH block. On Windows, never touch
   the machine-wide `Path`.

## Error handling

- Guards return 1 with a one-line `agentkit: …` message on stderr that names the
  fix (`Run ./install.sh --onboard`, `Add it to <env file>`, `run 'grok login'`).
- Installers never abort the whole run on one failure: they print
  `cli <name>: installer failed` with the vendor's docs link and continue.
- Wrappers `exec` the CLI as the last statement — no cleanup code after it.
- A mistyped verb exits non-zero and prints usage. Silence plus exit 0 reads
  exactly like success.

## Forbidden

- `command -v agent` as proof of Cursor (use the resolver).
- `pnpm add -g` without checking `pnpm root -g` first.
- `data = {}` on `JSONDecodeError`.
- Setting OpenCode's global `model` from a wrapper (pass `-m provider/model`).
- Adding a provider variant with no compatible endpoint.
- Markdown inside `bin/` or `lib/` other than `README.md` (the installer strips
  `*.md` from the PATH directory — the gate checks this).
- Hard-coding anyone's host, port, repository or employer. This kit ships no
  machine list; `agentbox` reads a file the user writes.
- A flag in a doc with no version and no link.

## Commits

Conventional commits: `type(scope): description`. Scopes: `bin`, `lib`, `win`,
`install`, `tests`, `docs`, `herdr`, `meta`.
