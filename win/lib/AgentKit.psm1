# AgentKit.psm1 — shared helpers for the Windows wrappers.
# Mirrors lib/common.sh. No secrets are printed, logged or written.

$script:KitName = 'agentkit'

function Get-AgentKitEnvFile {
    if ($env:AGENTKIT_ENV) { return $env:AGENTKIT_ENV }
    return (Join-Path $env:APPDATA 'coding-agents-kit\env')
}

function Get-AgentKitHome {
    if ($env:AGENTKIT_HOME) { return $env:AGENTKIT_HOME }
    return (Join-Path $env:LOCALAPPDATA 'coding-agents-kit')
}

function Get-AgentKitMachinesFile {
    if ($env:AGENTKIT_MACHINES) { return $env:AGENTKIT_MACHINES }
    return (Join-Path $env:APPDATA 'coding-agents-kit\machines.toml')
}

function Write-KitError {
    param([Parameter(Mandatory)][string]$Message)
    # One line, on stderr, naming the fix — the same contract the bash side has.
    [Console]::Error.WriteLine("$($script:KitName): $Message")
}

function Stop-Kit {
    param([Parameter(Mandatory)][string]$Message, [int]$Code = 1)
    Write-KitError $Message
    exit $Code
}

<#
.SYNOPSIS
Loads the user's env file into THIS process only.
.DESCRIPTION
Parses KEY=value lines: comments, blank lines, a leading `export `, surrounding
quotes and CRLF endings are all handled. A value is never echoed.
#>
function Import-AgentKitEnv {
    $file = Get-AgentKitEnvFile
    if (-not (Test-Path -LiteralPath $file)) { return }
    foreach ($raw in [System.IO.File]::ReadAllLines($file)) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        if ($line.StartsWith('export ')) { $line = $line.Substring(7).Trim() }
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) { continue }
        $name = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim()
        if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { continue }
        if ($value.Length -ge 2 -and (($value[0] -eq '"' -and $value[-1] -eq '"') -or
                                      ($value[0] -eq "'" -and $value[-1] -eq "'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        Set-Item -Path "env:$name" -Value $value
    }
}

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $cmd) {
        Stop-Kit "$Name is not on PATH. Run .\install.ps1 -Onboard, or see INSTALL.md."
    }
    return $cmd.Source
}

function Assert-EnvVar {
    param([Parameter(Mandatory)][string]$Name)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        Stop-Kit "$Name is not set. Add it to $(Get-AgentKitEnvFile)."
    }
    return $value
}

function Get-AzureBaseUrl {
    if ($env:AZURE_OPENAI_BASE_URL) { return $env:AZURE_OPENAI_BASE_URL }
    if ($env:AZURE_OPENAI_RESOURCE) {
        return "https://$($env:AZURE_OPENAI_RESOURCE).services.ai.azure.com/openai/v1"
    }
    Stop-Kit 'Set AZURE_OPENAI_RESOURCE or AZURE_OPENAI_BASE_URL.'
}

function Assert-AzureEnv {
    [void](Assert-EnvVar 'AZURE_OPENAI_API_KEY')
    [void](Get-AzureBaseUrl)
    # Deployment names are yours, so the kit cannot guess one.
    [void](Assert-EnvVar 'AZURE_OPENAI_MODEL_DAILY')
}

function Assert-XaiEnv { [void](Assert-EnvVar 'XAI_API_KEY') }
function Assert-ZaiEnv { [void](Assert-EnvVar 'ZAI_CODING_API_KEY') }

<#
.SYNOPSIS
Resolves the real Cursor Agent CLI — never the xAI Grok CLI.
.DESCRIPTION
Cursor installs both `agent` and `cursor-agent`; the Grok CLI also installs an
`agent`. So a bare `agent` on PATH is never proof that Cursor is installed.
Prefer the unambiguous name, reject anything whose path or version banner says
Grok, then fall back to Cursor's own versioned install directory.
#>
function Resolve-CursorBin {
    foreach ($name in @('cursor-agent', 'agent')) {
        $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) { continue }
        $path = $cmd.Source
        if ($path -match '[\\/]\.grok[\\/]' -or $path -match 'grok-(windows|macos|linux)') { continue }
        if ($path -match 'cursor-agent') { return $path }
        $banner = ''
        try { $banner = (& $path --version 2>$null | Select-Object -First 1) } catch { $banner = '' }
        if ($banner -match '^(?i)grok') { continue }
        return $path
    }
    foreach ($root in @("$env:LOCALAPPDATA\cursor-agent\versions", "$env:USERPROFILE\.local\share\cursor-agent\versions")) {
        if (Test-Path -LiteralPath $root) {
            $found = Get-ChildItem -LiteralPath $root -Recurse -Filter 'cursor-agent*' -ErrorAction SilentlyContinue |
                     Where-Object { -not $_.PSIsContainer } |
                     Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($found) { return $found.FullName }
        }
    }
    return $null
}

<#
.SYNOPSIS
Finds a Python 3 interpreter: the config writers are stdlib Python.
.OUTPUTS
An object with .Exe and .Args, so the `py -3` launcher works like a plain path.
#>
function Get-Python {
    foreach ($candidate in @('python3', 'python', 'py')) {
        $cmd = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $cmd) { continue }
        $pre = @()
        if ($candidate -eq 'py') { $pre = @('-3') }
        # The Microsoft Store alias stub answers `python` but runs nothing, so a
        # version probe is the only honest test.
        try {
            $out = & $cmd.Source @pre --version 2>&1
        } catch { continue }
        if ("$out" -match 'Python 3') {
            return [pscustomobject]@{ Exe = $cmd.Source; Args = $pre }
        }
    }
    Stop-Kit 'Python 3 is not on PATH (the provider config writers need it). winget install Python.Python.3.12'
}

function Invoke-KitWriter {
    param([Parameter(Mandatory)][string]$Script,
          [Parameter(ValueFromRemainingArguments)][string[]]$WriterArgs)
    $py = Get-Python
    $path = Join-Path (Join-Path (Get-AgentKitHome) 'lib') $Script
    if (-not (Test-Path -LiteralPath $path)) {
        # Running straight from a repo checkout rather than from an install.
        $repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $path = Join-Path (Join-Path $repo 'lib') $Script
    }
    if (-not (Test-Path -LiteralPath $path)) {
        Stop-Kit "config writer $Script not found — re-run .\install.ps1"
    }
    & $py.Exe @($py.Args) $path @WriterArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

<#
.SYNOPSIS
Warns when an executable still carries the browser's Mark-of-the-Web.
.DESCRIPTION
The Windows analogue of a broken code signature on macOS: a downloaded binary
that Windows still considers untrusted fails in ways that look like a bug in the
tool. Reported, never fixed silently — unblocking someone's binary is theirs to do.
#>
function Test-MarkOfTheWeb {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $zone = Get-Item -LiteralPath $Path -Stream 'Zone.Identifier' -ErrorAction SilentlyContinue
    } catch { return }
    if ($zone) {
        Write-KitError "$Path still carries the download mark (Zone.Identifier). If it fails to start: Unblock-File -LiteralPath '$Path'"
    }
}

Export-ModuleMember -Function *
