# Providers — Z.AI GLM, Azure OpenAI / Foundry, xAI

Every value lives in your env file (`env.example` carries the names only).
Wrappers export them for their own process and fail fast with the variable
**name** when something required is missing — never with the value.

> Model ids move. The defaults below are what the kit falls back to when you set
> nothing; check the provider's own model list and override in your env file.
> A model id is not a secret — put it in the env file and keep it current.

## Z.AI GLM Coding Plan

| Variable | Default | Used by |
| --- | --- | --- |
| `ZAI_CODING_API_KEY` | **required** | `claude-glm`, `codex-glm`, `opencode-glm`, `pi-glm` |
| `ZAI_DEFAULT_OPUS_MODEL` / `_SONNET_MODEL` / `_HAIKU_MODEL` | `glm-5.3` / `glm-5.3-flash` / `glm-5.3-flash` | all GLM wrappers |
| `ZAI_DEFAULT_FABLE_MODEL` | `glm-5.3` | `claude-glm` only (remaps the `fable` alias) |
| `ZAI_CODEX_DEFAULT_MODEL`, `ZAI_OPENCODE_DEFAULT_MODEL`, `ZAI_PI_DEFAULT_MODEL` | the sonnet value | per-CLI default |
| `ZAI_CODING_BASE_URL` | `https://api.z.ai/api/coding/paas/v4` | OpenCode, Pi |
| `ZAI_CODEX_BASE_URL` | `https://api.z.ai/api/v1` | Codex |
| `ZAI_CODING_API_TIMEOUT_MS` | `3000000` | `claude-glm` |
| `ZAI_CODING_AUTO_COMPACT_WINDOW` | unset | `claude-glm` (optional compaction window) |

Endpoints: an Anthropic-compatible one at `https://api.z.ai/api/anthropic` (for
Claude Code), an OpenAI-compatible coding endpoint (OpenCode, Pi), and
`api/v1` for Codex. Keys: <https://z.ai/manage-apikey/apikey-list>.

## Azure OpenAI / Microsoft Foundry

| Variable | Default | Notes |
| --- | --- | --- |
| `AZURE_OPENAI_API_KEY` | **required** | all `*-azure` |
| `AZURE_OPENAI_RESOURCE` **or** `AZURE_OPENAI_BASE_URL` | one is **required** | the resource builds `https://<resource>.services.ai.azure.com/openai/v1` |
| `AZURE_OPENAI_MODEL_DAILY` | **required** | this is your **deployment name**, not a model family — the kit cannot guess it |
| `AZURE_OPENAI_MODEL_REASONING` | falls back to daily | the second entry in the model list |
| `AZURE_OPENAI_DEFAULT_MODEL` | daily | which one a session starts on |

Provider ids: Codex `azure`, OpenCode `azure`, Pi `azure-foundry`, Cline
`openai` (Azure exposes an OpenAI-compatible surface).

## xAI

| Variable | Default | Notes |
| --- | --- | --- |
| `XAI_API_KEY` | required for `*-xai`; optional for `grokx` (OAuth) | |
| `XAI_BASE_URL` | `https://api.x.ai/v1` | |
| `XAI_MODEL_DAILY` / `XAI_MODEL_REASONING` | `grok-code-fast-1` / `grok-4` | the two whitelisted models |
| `XAI_DEFAULT_MODEL` | daily | which one a session starts on |

Keys: <https://console.x.ai/>. Provider ids: Codex `xai`, OpenCode `xai`, Pi
`xai-grok`, Cline `openai`. There is no Anthropic-compatible xAI endpoint, so
there is no `claudex-xai`.

## The daily / reasoning pair

Every provider here is configured with **two** models, both whitelisted, so you
can switch inside a session (`/model` in Codex and OpenCode, the cycle list in
Pi) without relaunching. `*_DEFAULT_MODEL` decides which one you start on. Keep
it on the cheaper one and escalate deliberately — that is the whole idea in
[`../model-strategy/README.md`](../model-strategy/README.md).

## Adding another OpenAI-compatible provider

Most providers today expose an OpenAI-compatible endpoint, which is exactly what
the three writers already emit. To add one:

1. Choose variable names (`FOO_API_KEY`, `FOO_BASE_URL`, `FOO_MODEL_DAILY`, …)
   and add them to `env.example`, commented, with a link to where the key comes from.
2. Add an `agentkit_require_foo` guard in `lib/common.sh`.
3. Copy the closest existing wrapper in `bin/` (`codex-xai`, `opencode-xai` and
   `pi-xai` are the simplest) and change the provider id, base URL and models.
4. Mirror it in `win/lib/Invoke-Wrapper.ps1` and add the `.cmd` shim.
5. Register the wrapper names in `lib/onboard.sh` and `win/lib/Onboard.psm1`.
6. Document it here and in [`wrappers-reference.md`](wrappers-reference.md), then
   run `tests/run.sh`.

## Matrix

| CLI | your login | GLM | Azure | xAI |
| --- | --- | --- | --- | --- |
| Claude Code | `claudex` | `claude-glm` | — | — |
| Codex | `codexx` | `codex-glm` | `codex-azure` | `codex-xai` |
| Cursor Agent | `cursorx` | — | — | — |
| OpenCode | `opencodex` | `opencode-glm` | `opencode-azure` | `opencode-xai` |
| Pi | `pix` | `pi-glm` | `pi-azure` | `pi-xai` |
| Cline | `clinex` | — | `cline-azure` | `cline-xai` |
| Grok | `grokx` | — | — | native |
