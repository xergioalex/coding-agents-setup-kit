<#
.SYNOPSIS
Idempotent installer / onboard for coding-agents-setup-kit on Windows.

.DESCRIPTION
Copies the wrapper shims and the config writers into %LOCALAPPDATA%, wires the
kit's bin directory into your USER Path, and creates the env file from
env.example when it does not exist. It never overwrites the env file, never
uninstalls or moves a CLI you already have, and never touches the machine-wide
Path.

.PARAMETER Onboard
Print what is already installed and the plan, then fill the gaps (this implies -Clis).

.PARAMETER Clis
Install the missing official CLIs this kit has a verified Windows path for, and
report the others with their official docs link.

.PARAMETER NoPath
Do not modify your user Path.

.EXAMPLE
.\install.ps1 -Onboard
#>
[CmdletBinding()]
param(
    [switch]$Onboard,
    [switch]$Clis,
    [switch]$NoPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = $PSScriptRoot
Import-Module (Join-Path $RepoRoot 'win\lib\AgentKit.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $RepoRoot 'win\lib\Onboard.psm1') -Force -DisableNameChecking
Import-AgentKitEnv

if ($Onboard) {
    Write-Output '=== Before ==='
    Show-AgentKitStatus
    Show-AgentKitPlan
    Write-Output ''
    Write-Output '=== Applying ==='
}

Copy-KitFiles -RepoRoot $RepoRoot
Copy-Item -Path (Join-Path $RepoRoot 'env.example') -Destination (Join-Path (Get-AgentKitHome) 'env.example') -Force
New-KitEnvFile -RepoRoot $RepoRoot
if (-not $NoPath) { Set-KitPath }
if ($Onboard -or $Clis) { Install-MissingClis }

Import-AgentKitEnv
Write-Output ''
Write-Output '=== After ==='
Show-AgentKitStatus
Show-AgentKitTodo
Write-Output ''
Write-Output "Open a NEW terminal, then: agentkit status"
Write-Output "Fill your keys locally in $(Get-AgentKitEnvFile) - never paste them into a chat."
