<#
Invoke-AgentBox.ps1 — Windows entry point for `agentbox`.

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
$rest = @()
if ($Rest) { $rest = @($Rest) }
& $py.Exe @($py.Args) $script @rest
exit $LASTEXITCODE
