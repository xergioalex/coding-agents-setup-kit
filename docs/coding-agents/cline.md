# Cline CLI (`cline`)

| | |
| --- | --- |
| Install (any OS) | `npm install -g cline` |
| Auth | `cline auth …` — the provider wrappers register an OpenAI-compatible provider |
| Config | Cline's own store |
| Verified against | install verified on macOS 2026-09-17 (3.0.62). **Flags unverified on host**: the binary would not start there — see below |
| Docs | <https://docs.cline.bot> |
| Herdr | detected; no integration |

## Flags the wrappers use

| Command / flag | Meaning |
| --- | --- |
| `cline --yolo` | full permissions |
| `cline auth -p openai -b <base> -k <key> -m <model>` | register an OpenAI-compatible provider |
| `cline --yolo -P openai -m <model> -k <key>` | launch with that provider |

## Wrappers

```bash
clinex                       # cline --yolo
cline-azure | clinex-azure   # auth + launch against Azure  (model: AZURE_OPENAI_DEFAULT_MODEL → daily)
cline-xai                    # auth + launch against xAI    (model: XAI_DEFAULT_MODEL → daily)
```

## The security caveat — the one exception in this kit

Cline receives the API key **on argv** (`-k`). It can appear in the process list
and in shell history. Every other provider wrapper in this kit passes an env
*reference* instead. Mitigations and the reasoning are in
[`../SECURITY.md`](../SECURITY.md); the short version:

- zsh `setopt HIST_IGNORE_SPACE` / bash `HISTCONTROL=ignorespace`, then type the
  command with a leading space;
- PowerShell: `Set-PSReadLineOption -HistorySaveStyle SaveNothing` for that session;
- or use `clinex` with Cline's own stored auth and skip the two provider wrappers.

If Cline gains an env-reference mechanism, this exception should disappear.

## A binary that will not start

On macOS (observed 2026-09-17, 3.0.62 on Apple silicon) the shipped executable
failed code-signature verification and the kernel killed it — `Killed: 9`, no
output. That is an upstream packaging defect, not a kit or npm-cache problem.
The kit's Cline wrappers verify the signature first and print the repair command
instead of forwarding an opaque `Killed: 9`:

```bash
codesign --verify --verbose=2 "$(readlink -f "$(command -v cline)")"
codesign --force --sign - <that path>     # ad-hoc re-sign; reversible by reinstalling
```

The Windows analogue is **Mark-of-the-Web / SmartScreen**: a freshly downloaded
binary that Windows still distrusts fails in equally confusing ways. The Windows
wrapper warns and prints `Unblock-File`. On Linux there is no equivalent check —
if the binary misbehaves, reinstall it from npm and check `npm view cline version`.
