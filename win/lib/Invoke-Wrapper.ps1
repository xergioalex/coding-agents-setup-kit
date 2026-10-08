<#
Invoke-Wrapper.ps1 - the Windows body of every wrapper in win/bin.

Each win/bin/<name>.cmd is a two-line shim that calls this file with its own
name. One file holds the dispatch so the Windows and the Unix wrappers cannot
drift: the flag mapping below is the same session-flag contract documented in
docs/STANDARDS.md.

  -c, --continue     continue the most recent session
  -r, --resume [id]  resume by id, or the CLI's picker
  -l                 Codex: resume --last;  Cursor: ls
  anything else      forwarded verbatim, after the kit's own flags
#>
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Wrapper,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'AgentKit.psm1') -Force -DisableNameChecking
Import-AgentKitEnv

$args_ = @()
if ($Rest) { $args_ = @($Rest) }

function Split-SessionFlag {
    <# Returns @{ Kind = 'continue'|'resume'|'list'|'none'; Id = <string|null>; Rest = @() } #>
    param([string[]]$Argv)
    $out = @{ Kind = 'none'; Id = $null; Rest = @($Argv) }
    if (-not $Argv -or $Argv.Count -eq 0) { return $out }
    switch ($Argv[0]) {
        { $_ -in @('-c', '--continue') } {
            $out.Kind = 'continue'; $out.Rest = @($Argv | Select-Object -Skip 1); return $out
        }
        { $_ -in @('-l', '--last', '--list') } {
            $out.Kind = 'list'; $out.Rest = @($Argv | Select-Object -Skip 1); return $out
        }
        { $_ -in @('-r', '--resume') } {
            $rest = @($Argv | Select-Object -Skip 1)
            if ($rest.Count -gt 0 -and -not $rest[0].StartsWith('-')) {
                $out.Id = $rest[0]; $rest = @($rest | Select-Object -Skip 1)
            }
            $out.Kind = 'resume'; $out.Rest = $rest; return $out
        }
    }
    return $out
}

function Invoke-Cli {
    param([Parameter(Mandatory)][string]$Exe, [string[]]$CliArgs)
    # PowerShell has no exec(): this process stays as the parent. Herdr detects
    # the foreground process in a pane, so a wrapper used inside Herdr on Windows
    # may need HERDR_AGENT=<kind> - see docs/herdr/06-agent-automation.md.
    & $Exe @CliArgs
    exit $LASTEXITCODE
}

$session = Split-SessionFlag $args_

switch ($Wrapper) {

    # ---------------------------------------------------------------- Claude
    { $_ -in @('claudex') } {
        $exe = Assert-Command 'claude'
        $flags = @('--dangerously-skip-permissions')
        switch ($session.Kind) {
            'continue' { Invoke-Cli $exe (@('--continue') + $flags + $session.Rest) }
            'resume'   {
                $pre = @('--resume')
                if ($session.Id) { $pre += $session.Id }
                Invoke-Cli $exe ($pre + $flags + $session.Rest)
            }
            default    { Invoke-Cli $exe ($flags + $args_) }
        }
    }

    { $_ -in @('claude-glm', 'claudex-glm') } {
        $exe = Assert-Command 'claude'
        Assert-ZaiEnv
        # Process-scoped only: plain `claude` keeps the user's Anthropic login.
        $env:ANTHROPIC_AUTH_TOKEN = $env:ZAI_CODING_API_KEY
        $env:ANTHROPIC_BASE_URL = 'https://api.z.ai/api/anthropic'
        $env:API_TIMEOUT_MS = if ($env:ZAI_CODING_API_TIMEOUT_MS) { $env:ZAI_CODING_API_TIMEOUT_MS } else { '3000000' }
        # Tier mapping for the current GLM Coding Plan: flagship glm-5.3 for the
        # opus and fable aliases, glm-5.3-flash for sonnet and haiku.
        $opus   = if ($env:ZAI_DEFAULT_OPUS_MODEL)   { $env:ZAI_DEFAULT_OPUS_MODEL }   else { 'glm-5.3' }
        $fable  = if ($env:ZAI_DEFAULT_FABLE_MODEL)  { $env:ZAI_DEFAULT_FABLE_MODEL }  else { 'glm-5.3' }
        $sonnet = if ($env:ZAI_DEFAULT_SONNET_MODEL) { $env:ZAI_DEFAULT_SONNET_MODEL } else { 'glm-5.3-flash' }
        $haiku  = if ($env:ZAI_DEFAULT_HAIKU_MODEL)  { $env:ZAI_DEFAULT_HAIKU_MODEL }  else { 'glm-5.3-flash' }
        $env:ANTHROPIC_DEFAULT_OPUS_MODEL = $opus
        $env:ANTHROPIC_DEFAULT_FABLE_MODEL = $fable
        $env:ANTHROPIC_DEFAULT_SONNET_MODEL = $sonnet
        $env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $haiku
        if ($env:ZAI_CODING_AUTO_COMPACT_WINDOW) {
            $env:CLAUDE_CODE_AUTO_COMPACT_WINDOW = $env:ZAI_CODING_AUTO_COMPACT_WINDOW
        }
        Invoke-Cli $exe (@('--dangerously-skip-permissions') + $args_)
    }

    # ----------------------------------------------------------------- Codex
    { $_ -in @('codexx', 'codex-azure', 'codex-xai', 'codex-glm') } {
        $exe = Assert-Command 'codex'
        $bypass = @('--dangerously-bypass-approvals-and-sandbox')
        $profileArgs = @()
        $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }

        switch ($Wrapper) {
            'codex-azure' {
                Assert-AzureEnv
                $model = if ($env:AZURE_OPENAI_DEFAULT_MODEL) { $env:AZURE_OPENAI_DEFAULT_MODEL } else { $env:AZURE_OPENAI_MODEL_DAILY }
                Invoke-KitWriter 'write_codex_profile.py' (Join-Path $codexHome 'azure.config.toml') `
                    'azure' 'Azure OpenAI / Microsoft Foundry' (Get-AzureBaseUrl) 'AZURE_OPENAI_API_KEY' $model
                $profileArgs = @('-p', 'azure')
            }
            'codex-xai' {
                Assert-XaiEnv
                $base = if ($env:XAI_BASE_URL) { $env:XAI_BASE_URL } else { 'https://api.x.ai/v1' }
                $model = if ($env:XAI_DEFAULT_MODEL) { $env:XAI_DEFAULT_MODEL }
                         elseif ($env:XAI_MODEL_DAILY) { $env:XAI_MODEL_DAILY } else { 'grok-code-fast-1' }
                Invoke-KitWriter 'write_codex_profile.py' (Join-Path $codexHome 'xai.config.toml') `
                    'xai' 'xAI Grok' $base 'XAI_API_KEY' $model
                $profileArgs = @('-p', 'xai')
            }
            'codex-glm' {
                Assert-ZaiEnv
                $base = if ($env:ZAI_CODEX_BASE_URL) { $env:ZAI_CODEX_BASE_URL } else { 'https://api.z.ai/api/v1' }
                $model = if ($env:ZAI_CODEX_DEFAULT_MODEL) { $env:ZAI_CODEX_DEFAULT_MODEL }
                         elseif ($env:ZAI_DEFAULT_SONNET_MODEL) { $env:ZAI_DEFAULT_SONNET_MODEL } else { 'glm-5.3-flash' }
                Invoke-KitWriter 'write_codex_profile.py' (Join-Path $codexHome 'glm.config.toml') `
                    'ZAI' 'Z.AI GLM Coding Plan' $base 'ZAI_CODING_API_KEY' $model
                $profileArgs = @('-p', 'glm')
            }
        }

        switch ($session.Kind) {
            'continue' { Invoke-Cli $exe ($profileArgs + @('resume', '--last') + $bypass + $session.Rest) }
            'list'     { Invoke-Cli $exe ($profileArgs + @('resume', '--last') + $bypass + $session.Rest) }
            'resume'   {
                $tail = if ($session.Id) { @('resume', $session.Id) } else { @('resume', '--all') }
                Invoke-Cli $exe ($profileArgs + $tail + $bypass + $session.Rest)
            }
            default    { Invoke-Cli $exe ($profileArgs + $bypass + $args_) }
        }
    }

    # ---------------------------------------------------------------- Cursor
    'cursorx' {
        $exe = Resolve-CursorBin
        if (-not $exe) {
            Stop-Kit 'Cursor Agent CLI not found (looked for cursor-agent, then a non-Grok agent). Install: https://cursor.com/docs/cli'
        }
        $flags = @('--force')
        if ($env:CURSORX_SANDBOX) { $flags += @('--sandbox', $env:CURSORX_SANDBOX) }
        switch ($session.Kind) {
            'continue' { Invoke-Cli $exe (@('--continue') + $flags + $session.Rest) }
            'list'     { Invoke-Cli $exe (@('ls') + $session.Rest) }
            'resume'   {
                $pre = if ($session.Id) { @("--resume=$($session.Id)") } else { @('--resume') }
                Invoke-Cli $exe ($pre + $flags + $session.Rest)
            }
            default    { Invoke-Cli $exe ($flags + $args_) }
        }
    }

    # -------------------------------------------------------------- OpenCode
    { $_ -in @('opencodex', 'opencode-azure', 'opencode-xai', 'opencode-glm') } {
        $exe = Assert-Command 'opencode'
        $config = if ($env:OPENCODE_CONFIG) { $env:OPENCODE_CONFIG } else { Join-Path $env:APPDATA 'opencode\opencode.json' }
        $modelArgs = @()
        switch ($Wrapper) {
            'opencode-azure' {
                Assert-AzureEnv
                $daily = $env:AZURE_OPENAI_MODEL_DAILY
                $reasoning = if ($env:AZURE_OPENAI_MODEL_REASONING) { $env:AZURE_OPENAI_MODEL_REASONING } else { $daily }
                $default = if ($env:AZURE_OPENAI_DEFAULT_MODEL) { $env:AZURE_OPENAI_DEFAULT_MODEL } else { $daily }
                Invoke-KitWriter 'write_opencode_provider.py' $config 'azure' 'AZURE_OPENAI_API_KEY' (Get-AzureBaseUrl) $daily $reasoning
                $modelArgs = @('-m', "azure/$default")
            }
            'opencode-xai' {
                Assert-XaiEnv
                $base = if ($env:XAI_BASE_URL) { $env:XAI_BASE_URL } else { 'https://api.x.ai/v1' }
                $daily = if ($env:XAI_MODEL_DAILY) { $env:XAI_MODEL_DAILY } else { 'grok-code-fast-1' }
                $reasoning = if ($env:XAI_MODEL_REASONING) { $env:XAI_MODEL_REASONING } else { 'grok-4' }
                $default = if ($env:XAI_DEFAULT_MODEL) { $env:XAI_DEFAULT_MODEL } else { $daily }
                Invoke-KitWriter 'write_opencode_provider.py' $config 'xai' 'XAI_API_KEY' $base $daily $reasoning
                $modelArgs = @('-m', "xai/$default")
            }
            'opencode-glm' {
                Assert-ZaiEnv
                $base = if ($env:ZAI_CODING_BASE_URL) { $env:ZAI_CODING_BASE_URL } else { 'https://api.z.ai/api/coding/paas/v4' }
                $sonnet = if ($env:ZAI_DEFAULT_SONNET_MODEL) { $env:ZAI_DEFAULT_SONNET_MODEL } else { 'glm-5.3-flash' }
                $opus   = if ($env:ZAI_DEFAULT_OPUS_MODEL)   { $env:ZAI_DEFAULT_OPUS_MODEL }   else { 'glm-5.3' }
                $haiku  = if ($env:ZAI_DEFAULT_HAIKU_MODEL)  { $env:ZAI_DEFAULT_HAIKU_MODEL }  else { 'glm-5.3-flash' }
                $default = if ($env:ZAI_OPENCODE_DEFAULT_MODEL) { $env:ZAI_OPENCODE_DEFAULT_MODEL } else { $sonnet }
                Invoke-KitWriter 'write_opencode_provider.py' $config 'zai-coding-plan' 'ZAI_CODING_API_KEY' $base $sonnet $opus $haiku
                $env:ZHIPU_API_KEY = $env:ZAI_CODING_API_KEY
                $env:ZAI_API_KEY = $env:ZAI_CODING_API_KEY
                $modelArgs = @('-m', "zai-coding-plan/$default")
            }
        }
        Invoke-Cli $exe (@('--auto') + $modelArgs + $args_)
    }

    # -------------------------------------------------------------------- Pi
    { $_ -in @('pix', 'pi-azure', 'pi-xai', 'pi-glm') } {
        $exe = Assert-Command 'pi'
        $models = if ($env:PI_MODELS_FILE) { $env:PI_MODELS_FILE } else { Join-Path $env:USERPROFILE '.pi\agent\models.json' }
        $providerArgs = @()
        switch ($Wrapper) {
            'pi-azure' {
                Assert-AzureEnv
                $daily = $env:AZURE_OPENAI_MODEL_DAILY
                $reasoning = if ($env:AZURE_OPENAI_MODEL_REASONING) { $env:AZURE_OPENAI_MODEL_REASONING } else { $daily }
                $default = if ($env:AZURE_OPENAI_DEFAULT_MODEL) { $env:AZURE_OPENAI_DEFAULT_MODEL } else { $daily }
                Invoke-KitWriter 'write_pi_provider.py' $models 'azure-foundry' (Get-AzureBaseUrl) 'AZURE_OPENAI_API_KEY' `
                    '200000' '32768' 'true' "${daily}:daily" "${reasoning}:reasoning"
                $providerArgs = @('--provider', 'azure-foundry', '--model', $default, '--models', "azure-foundry/$daily,azure-foundry/$reasoning")
            }
            'pi-xai' {
                Assert-XaiEnv
                $base = if ($env:XAI_BASE_URL) { $env:XAI_BASE_URL } else { 'https://api.x.ai/v1' }
                $daily = if ($env:XAI_MODEL_DAILY) { $env:XAI_MODEL_DAILY } else { 'grok-code-fast-1' }
                $reasoning = if ($env:XAI_MODEL_REASONING) { $env:XAI_MODEL_REASONING } else { 'grok-4' }
                $default = if ($env:XAI_DEFAULT_MODEL) { $env:XAI_DEFAULT_MODEL } else { $daily }
                Invoke-KitWriter 'write_pi_provider.py' $models 'xai-grok' $base 'XAI_API_KEY' `
                    '200000' '32768' 'true' "${daily}:daily" "${reasoning}:reasoning"
                $providerArgs = @('--provider', 'xai-grok', '--model', $default, '--models', "xai-grok/$daily,xai-grok/$reasoning")
            }
            'pi-glm' {
                Assert-ZaiEnv
                $base = if ($env:ZAI_CODING_BASE_URL) { $env:ZAI_CODING_BASE_URL } else { 'https://api.z.ai/api/coding/paas/v4' }
                $sonnet = if ($env:ZAI_DEFAULT_SONNET_MODEL) { $env:ZAI_DEFAULT_SONNET_MODEL } else { 'glm-5.3-flash' }
                $opus   = if ($env:ZAI_DEFAULT_OPUS_MODEL)   { $env:ZAI_DEFAULT_OPUS_MODEL }   else { 'glm-5.3' }
                $haiku  = if ($env:ZAI_DEFAULT_HAIKU_MODEL)  { $env:ZAI_DEFAULT_HAIKU_MODEL }  else { 'glm-5.3-flash' }
                $default = if ($env:ZAI_PI_DEFAULT_MODEL) { $env:ZAI_PI_DEFAULT_MODEL } else { $sonnet }
                Invoke-KitWriter 'write_pi_provider.py' $models 'zai-glm' $base 'ZAI_CODING_API_KEY' `
                    '200000' '131072' 'false' "${sonnet}:sonnet" "${opus}:opus" "${haiku}:haiku"
                $env:ZAI_API_KEY = $env:ZAI_CODING_API_KEY
                $list = @("zai-glm/$sonnet")
                foreach ($id in @($opus, $haiku)) {
                    if ($list -notcontains "zai-glm/$id") { $list += "zai-glm/$id" }
                }
                $providerArgs = @('--provider', 'zai-glm', '--model', $default, '--models', ($list -join ','))
            }
        }
        Invoke-Cli $exe (@('--approve') + $providerArgs + $args_)
    }

    # ----------------------------------------------------------------- Cline
    { $_ -in @('clinex', 'cline-azure', 'clinex-azure', 'cline-xai') } {
        $exe = Assert-Command 'cline'
        Test-MarkOfTheWeb $exe
        if ($Wrapper -eq 'clinex') {
            Invoke-Cli $exe (@('--yolo') + $args_)
        }
        # Cline takes the key on argv - the one documented exception in this kit.
        # It can appear in the process list and in PSReadLine history.
        if ($Wrapper -eq 'cline-xai') {
            Assert-XaiEnv
            $base = if ($env:XAI_BASE_URL) { $env:XAI_BASE_URL } else { 'https://api.x.ai/v1' }
            $model = if ($env:XAI_DEFAULT_MODEL) { $env:XAI_DEFAULT_MODEL }
                     elseif ($env:XAI_MODEL_DAILY) { $env:XAI_MODEL_DAILY } else { 'grok-code-fast-1' }
            $key = $env:XAI_API_KEY
        } else {
            Assert-AzureEnv
            $base = Get-AzureBaseUrl
            $model = if ($env:AZURE_OPENAI_DEFAULT_MODEL) { $env:AZURE_OPENAI_DEFAULT_MODEL } else { $env:AZURE_OPENAI_MODEL_DAILY }
            $key = $env:AZURE_OPENAI_API_KEY
        }
        & $exe auth -p openai -b $base -k $key -m $model
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        Invoke-Cli $exe (@('--yolo', '-P', 'openai', '-m', $model, '-k', $key) + $args_)
    }

    # ------------------------------------------------------------------ Grok
    'grokx' {
        $exe = Assert-Command 'grok'
        if (-not $env:XAI_API_KEY -and -not (Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.grok\auth.json'))) {
            Write-KitError "no XAI_API_KEY in env and no Grok login found - run 'grok login' or set XAI_API_KEY in $(Get-AgentKitEnvFile)."
        }
        switch ($session.Kind) {
            'continue' { Invoke-Cli $exe (@('--continue') + $session.Rest) }
            'resume'   {
                $pre = @('--resume')
                if ($session.Id) { $pre += $session.Id }
                Invoke-Cli $exe ($pre + $session.Rest)
            }
            default    { Invoke-Cli $exe $args_ }
        }
    }

    default {
        Stop-Kit "unknown wrapper '$Wrapper' (this file is called by win/bin/<name>.cmd)"
    }
}
