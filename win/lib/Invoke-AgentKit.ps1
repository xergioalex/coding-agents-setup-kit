<#
Invoke-AgentKit.ps1 - the kit doctor on Windows: `agentkit status|doctor|onboard|path|env-path`.

Reports what is installed and which keys are set BY NAME. It never prints a
value, and `status` writes nothing at all.
#>
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest)
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'AgentKit.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'Onboard.psm1') -Force -DisableNameChecking
Import-AgentKitEnv

# PowerShell variable names are case-insensitive: a local named $rest IS the
# $Rest parameter, and resetting it would silently drop every argument.
$argv_ = @()
if ($Rest) { $argv_ = @($Rest) }
$cmd = if ($argv_.Count -gt 0) { $argv_[0] } else { 'status' }
$tail = @()
if ($argv_.Count -gt 1) { $tail = @($argv_ | Select-Object -Skip 1) }

function Show-Usage {
@'
agentkit status | doctor | onboard [-Clis] | path | env-path | machines-path

  status     Detect which official CLIs, wrappers, PATH and env keys exist
             (never prints secret values). Run this first on a new machine.
  doctor     Alias of status.
  onboard    Report what is installed, then say what is left for you to do.
             -Clis also installs the missing official CLIs.
  path       Print the kit bin directory
  env-path   Print the env file path
  machines-path  Print the machines file path (used by agentbox)
'@
}

switch ($cmd) {
    { $_ -in @('-h', '--help', 'help') } { Show-Usage; exit 0 }
    'path'          { Write-Output (Join-Path (Get-AgentKitHome) 'bin'); exit 0 }
    'env-path'      { Write-Output (Get-AgentKitEnvFile); exit 0 }
    'machines-path' { Write-Output (Get-AgentKitMachinesFile); exit 0 }
    { $_ -in @('status', 'doctor') } {
        Show-AgentKitStatus
        Show-AgentKitPlan
        exit 0
    }
    'onboard' {
        $installClis = ($tail -contains '-Clis') -or ($tail -contains '--clis')
        Show-AgentKitStatus
        Show-AgentKitPlan
        if ($installClis) { Install-MissingClis }
        Show-AgentKitTodo
        exit 0
    }
    default {
        # A mistyped verb must not look like success.
        Write-KitError "unknown command $cmd"
        Show-Usage | Write-Output
        exit 1
    }
}
