<#
Invoke-AgentBox.ps1 - Windows entry point for `agentbox`.

The command itself is stdlib Python (../lib/agentbox.py, shared byte-for-byte
with macOS and Linux); this file only finds a Python 3 and forwards.
#>
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'AgentKit.psm1') -Force -DisableNameChecking

$script = Join-Path $PSScriptRoot 'agentbox.py'
if (-not (Test-Path -LiteralPath $script)) {
    # Repo checkout: win/lib/.. /.. /lib/agentbox.py
    $repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $script = Join-Path (Join-Path $repo 'lib') 'agentbox.py'
}
if (-not (Test-Path -LiteralPath $script)) { Stop-Kit 'agentbox.py not found - re-run .\install.ps1' }

$py = Get-Python
# agentbox.py defaults to ~/.config/...; on Windows the documented location is
# %APPDATA%\coding-agents-kit\machines.toml, the same file `agentkit status` reads.
$env:AGENTKIT_MACHINES = Get-AgentKitMachinesFile
# Not $rest: PowerShell names are case-insensitive, so that would reset $Rest.
$argv_ = @()
if ($Rest) { $argv_ = @($Rest) }
& $py.Exe @($py.Args) $script @argv_
exit $LASTEXITCODE
