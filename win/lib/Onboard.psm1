# Onboard.psm1 - detection and gap-fill on Windows. Mirrors lib/onboard.sh.
# Never prints a secret value; never uninstalls or moves anything.

Import-Module (Join-Path $PSScriptRoot 'AgentKit.psm1') -Force -DisableNameChecking

$script:Clis = @('claude', 'codex', 'cursor-agent', 'opencode', 'pi', 'cline', 'grok', 'herdr')
$script:Wrappers = @(
    'claudex', 'claude-glm', 'claudex-glm',
    'codexx', 'codex-azure', 'codex-xai', 'codex-glm',
    'cursorx',
    'opencodex', 'opencode-azure', 'opencode-xai', 'opencode-glm',
    'pix', 'pi-azure', 'pi-xai', 'pi-glm',
    'clinex', 'cline-azure', 'cline-xai', 'clinex-azure',
    'grokx',
    'agentbox', 'agentkit'
)
$script:EnvKeys = @('ZAI_CODING_API_KEY', 'XAI_API_KEY', 'AZURE_OPENAI_API_KEY')
$script:Todo = New-Object System.Collections.ArrayList

# How each CLI is installed on Windows. Where this kit has no verified native
# installer it says so and links the vendor - it never guesses a package name.
$script:CliInstall = @{
    'claude'       = @{ Kind = 'script'; Command = 'irm https://claude.ai/install.ps1 | iex'; Docs = 'https://docs.claude.com/en/docs/claude-code' }
    'codex'        = @{ Kind = 'npm';    Package = '@openai/codex'; Docs = 'https://developers.openai.com/codex/cli' }
    'cline'        = @{ Kind = 'npm';    Package = 'cline'; Docs = 'https://docs.cline.bot' }
    'pi'           = @{ Kind = 'npm';    Package = '@earendil-works/pi-coding-agent'; Extra = @('--ignore-scripts'); Docs = 'https://www.npmjs.com/package/@earendil-works/pi-coding-agent' }
    'cursor-agent' = @{ Kind = 'script'; Command = "irm 'https://cursor.com/install?win32=true' | iex"; Docs = 'https://cursor.com/docs/cli' }
    'opencode'     = @{ Kind = 'npm';    Package = 'opencode-ai'; Docs = 'https://opencode.ai/docs' }
    'grok'         = @{ Kind = 'script'; Command = 'irm https://x.ai/cli/install.ps1 | iex'; Docs = 'https://x.ai/cli' }
    'herdr'        = @{ Kind = 'manual'; Docs = 'https://herdr.dev/docs/install/' }
}

function Add-Todo {
    param([string]$What, [string]$How)
    [void]$script:Todo.Add(@{ What = $What; How = $How })
}

function Get-CliPath {
    param([Parameter(Mandatory)][string]$Name)
    if ($Name -eq 'cursor-agent') { return (Resolve-CursorBin) }
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Test-KitOnPath {
    $bin = Join-Path (Get-AgentKitHome) 'bin'
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { return $false }
    return (($userPath -split ';') -contains $bin)
}

function Show-AgentKitStatus {
    $dest = Get-AgentKitHome
    $envFile = Get-AgentKitEnvFile

    Write-Output '## Host'
    Write-Output ("os: windows`tps: {0}" -f $PSVersionTable.PSVersion)

    Write-Output ''
    Write-Output '## Prerequisites'
    $py = Find-Python
    if ($py) { Write-Output ("tool python: installed`t{0} {1}" -f $py.Exe, ($py.Args -join ' ')).TrimEnd() }
    else     { Write-Output 'tool python: missing (the Microsoft Store alias does not count) - winget install Python.Python.3.12' }
    foreach ($tool in @('git', 'node', 'npm', 'docker', 'ssh', 'wsl', 'winget')) {
        $cmd = Get-Command $tool -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { Write-Output ("tool {0}: installed`t{1}" -f $tool, $cmd.Source) }
        else      { Write-Output ("tool {0}: missing" -f $tool) }
    }

    Write-Output ''
    Write-Output '## CLIs (official binaries)'
    foreach ($cli in $script:Clis) {
        $path = Get-CliPath $cli
        if ($path) { Write-Output ("cli {0}: installed`t{1}" -f $cli, $path) }
        else       { Write-Output ("cli {0}: missing" -f $cli) }
    }
    $agent = Get-Command 'agent' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($agent) {
        $cursor = Resolve-CursorBin
        if (-not $cursor -or $cursor -ne $agent.Source) {
            Write-Output ("note: 'agent' on PATH ({0}) may be the xAI Grok CLI, not Cursor - cursorx resolves Cursor itself" -f $agent.Source)
        }
    }

    Write-Output ''
    Write-Output '## Wrappers (this kit)'
    foreach ($w in $script:Wrappers) {
        $cmd = Get-Command $w -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $installed = Join-Path (Join-Path $dest 'bin') "$w.cmd"
        if ($cmd) { Write-Output ("wrapper {0}: on PATH`t{1}" -f $w, $cmd.Source) }
        elseif (Test-Path -LiteralPath $installed) { Write-Output ("wrapper {0}: installed, not on PATH`t{1}" -f $w, $installed) }
        else { Write-Output ("wrapper {0}: missing" -f $w) }
    }

    Write-Output ''
    Write-Output '## Env'
    if (Test-Path -LiteralPath $envFile) {
        $hasValues = (Select-String -LiteralPath $envFile -Pattern '^[A-Za-z_][A-Za-z0-9_]*=' -Quiet)
        if ($hasValues) { Write-Output 'env file: present (values not shown)' }
        else { Write-Output "env file: present but every line is commented - edit $envFile to enable keys" }
    } else {
        Write-Output 'env file: missing'
    }
    foreach ($name in $script:EnvKeys) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if ([string]::IsNullOrWhiteSpace($value)) { Write-Output "env ${name}: unset" }
        else { Write-Output "env ${name}: set" }
    }
    if ($env:AZURE_OPENAI_RESOURCE -or $env:AZURE_OPENAI_BASE_URL) {
        Write-Output 'env AZURE_OPENAI_RESOURCE/BASE_URL: set'
    } else {
        Write-Output 'env AZURE_OPENAI_RESOURCE/BASE_URL: unset'
    }
    if (Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.grok\auth.json')) {
        Write-Output 'grok login: present (grokx works without XAI_API_KEY)'
    }

    Write-Output ''
    Write-Output '## Machines'
    $machines = Get-AgentKitMachinesFile
    if (Test-Path -LiteralPath $machines) { Write-Output ("machines file: present`t{0}" -f $machines) }
    else { Write-Output 'machines file: none (optional - agentbox needs one; see machines.example.toml)' }

    Write-Output ''
    Write-Output '## PATH'
    if (Test-KitOnPath) { Write-Output 'user PATH: wired' } else { Write-Output 'user PATH: not wired' }
    Write-Output "kit dest: $dest"
}

function Show-AgentKitPlan {
    $present = @(); $missing = @()
    foreach ($cli in $script:Clis) {
        if (Get-CliPath $cli) { $present += $cli } else { $missing += $cli }
    }
    Write-Output ''
    Write-Output '## Onboard plan'
    if ($present.Count) { Write-Output ("keep CLIs (already installed): {0}" -f ($present -join ' ')) }
    else { Write-Output 'keep CLIs (already installed): none' }
    if ($missing.Count) { Write-Output ("install CLIs (missing): {0}" -f ($missing -join ' ')) }
    else { Write-Output 'install CLIs (missing): none' }
    Write-Output 'refresh wrappers: .\install.ps1 copies them (idempotent; removes no CLI)'
    if (Test-Path -LiteralPath (Get-AgentKitEnvFile)) {
        Write-Output 'env file: present; .\install.ps1 keeps it (never overwrites)'
    } else {
        Write-Output 'env file: missing; .\install.ps1 creates it from env.example (names only)'
    }
    if (Test-KitOnPath) { Write-Output 'PATH: already wired' }
    else { Write-Output 'PATH: not wired; .\install.ps1 appends the kit bin dir to your USER Path' }
}

function Show-AgentKitTodo {
    # Env file and PATH are judged now, not when the plan was printed: by the
    # time this runs the installer has usually just fixed both.
    $envFile = Get-AgentKitEnvFile
    if (-not (Test-Path -LiteralPath $envFile)) {
        Add-Todo 'no env file yet, so provider wrappers have nothing to read' 'run .\install.ps1 (it creates the file with names only)'
    } elseif (-not (Select-String -LiteralPath $envFile -Pattern '^[A-Za-z_][A-Za-z0-9_]*=' -Quiet)) {
        Add-Todo 'the env file has no keys yet, so the -glm/-xai/-azure wrappers will refuse to start' "edit $envFile yourself (agentkit env-path prints it); never paste a key into a chat"
    }
    if (-not (Test-KitOnPath)) {
        Add-Todo "the kit's bin directory is not on your PATH" 'run .\install.ps1, then open a new terminal'
    }
    Write-Output ''
    Write-Output '## what is left'
    if ($script:Todo.Count -eq 0) {
        Write-Output '  nothing - this machine is set up.'
        return
    }
    foreach ($item in $script:Todo) {
        Write-Output ("  - {0}" -f $item.What)
        Write-Output ("    -> {0}" -f $item.How)
    }
}

function Install-MissingClis {
    $npm = Get-Command npm -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    foreach ($cli in $script:Clis) {
        if (Get-CliPath $cli) { Write-Output "cli ${cli}: already installed - skip"; continue }
        $spec = $script:CliInstall[$cli]
        switch ($spec.Kind) {
            'npm' {
                if (-not $npm) {
                    Write-Output "cli ${cli}: needs npm - winget install OpenJS.NodeJS.LTS"
                    Add-Todo "$cli needs Node/npm" 'winget install OpenJS.NodeJS.LTS, then re-run .\install.ps1 -Clis'
                    break
                }
                Write-Output "cli ${cli}: installing (npm install -g $($spec.Package))..."
                $npmArgs = @('install', '-g')
                if ($spec.Extra) { $npmArgs += $spec.Extra }
                $npmArgs += $spec.Package
                & $npm.Source @npmArgs
                if ($LASTEXITCODE -ne 0) { Write-Output "cli ${cli}: install failed - see $($spec.Docs)" }
            }
            'script' {
                Write-Output "cli ${cli}: installing ($($spec.Command))..."
                try {
                    Invoke-Expression $spec.Command
                } catch {
                    Write-Output "cli ${cli}: installer failed - see $($spec.Docs)"
                    Add-Todo "$cli did not install" "follow $($spec.Docs)"
                    break
                }
                # A vendor script can print success after a failed download (Cursor's
                # does), so trust only what is on PATH afterwards. Vendors edit the
                # USER Path; pick that up for this process.
                $env:Path = "$env:Path;$([Environment]::GetEnvironmentVariable('Path', 'User'))"
                if (-not (Get-CliPath $cli)) {
                    Write-Output "cli ${cli}: the installer finished but $cli is still not found - see $($spec.Docs)"
                    Add-Todo "$cli did not install (its installer reported no error)" "re-run .\install.ps1 -Clis, or follow $($spec.Docs)"
                }
            }
            default {
                # No verified native Windows installer in this kit: say so, link
                # the vendor, and mention WSL. Guessing a package name would be
                # worse than an honest gap.
                Write-Output "cli ${cli}: no verified native Windows installer in this kit - see $($spec.Docs)"
                Add-Todo "$cli is not installed and this kit has no verified Windows installer for it" `
                         "install it from $($spec.Docs), or run it inside WSL (docs/WINDOWS.md)"
            }
        }
    }
}

function Copy-KitFiles {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $dest = Get-AgentKitHome
    $bin = Join-Path $dest 'bin'
    $lib = Join-Path $dest 'lib'
    New-Item -ItemType Directory -Force -Path $bin, $lib | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot 'win\bin\*.cmd') -Destination $bin -Force
    Copy-Item -Path (Join-Path $RepoRoot 'win\lib\*') -Destination $lib -Force
    Copy-Item -Path (Join-Path $RepoRoot 'lib\*.py') -Destination $lib -Force
    # Git Bash cannot run foo.cmd as `foo`, so each wrapper also gets an
    # extensionless bash shim beside it (LF, no BOM). PowerShell and cmd.exe
    # still pick the .cmd first.
    $template = [System.IO.File]::ReadAllText((Join-Path $RepoRoot 'win\lib\bash-shim.sh')) -replace "`r`n", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    foreach ($cmdFile in Get-ChildItem -Path (Join-Path $RepoRoot 'win\bin\*.cmd')) {
        $name = $cmdFile.BaseName
        [System.IO.File]::WriteAllText((Join-Path $bin $name), $template.Replace('__NAME__', $name), $utf8NoBom)
    }
    Write-Output "wrappers: refreshed in $bin (.cmd for PowerShell/cmd, extensionless for Git Bash)"
}

function Set-KitPath {
    $bin = Join-Path (Get-AgentKitHome) 'bin'
    # Read-modify-write of the USER Path only. The machine Path is never touched,
    # and an existing entry is never rewritten.
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($null -eq $current) { $current = '' }
    if (($current -split ';') -contains $bin) {
        Write-Output "PATH: already contains $bin"
        return
    }
    $backup = Join-Path (Get-AgentKitHome) 'path-backup.txt'
    Set-Content -LiteralPath $backup -Value $current -Encoding UTF8
    $new = if ([string]::IsNullOrEmpty($current)) { $bin } else { "$current;$bin" }
    [Environment]::SetEnvironmentVariable('Path', $new, 'User')
    $env:Path = "$bin;$env:Path"
    Write-Output "PATH: appended $bin to your user Path (previous value saved to $backup)"
    Write-Output 'PATH: open a NEW terminal for it to take effect everywhere'
}

function New-KitEnvFile {
    param([Parameter(Mandatory)][string]$RepoRoot)
    $envFile = Get-AgentKitEnvFile
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $envFile) | Out-Null
    if (Test-Path -LiteralPath $envFile) {
        Write-Output "env file: kept $envFile (not overwritten)"
        return
    }
    Copy-Item -Path (Join-Path $RepoRoot 'env.example') -Destination $envFile -Force
    # The Unix side uses chmod 600; on Windows the equivalent is an ACL that
    # grants this user only, with inheritance removed.
    try {
        $acl = Get-Acl -LiteralPath $envFile
        $acl.SetAccessRuleProtection($true, $false)
        foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRule($rule) }
        $me = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')
        $acl.AddAccessRule($rule)
        Set-Acl -LiteralPath $envFile -AclObject $acl
        Write-Output "env file: created $envFile (locked to $me)"
    } catch {
        Write-Output "env file: created $envFile"
        Write-KitError "could not restrict the ACL on $envFile - do it yourself: icacls `"$envFile`" /inheritance:r /grant:r `"%USERNAME%:F`""
    }
}

Export-ModuleMember -Function *
