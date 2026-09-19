@echo off
rem agentkit - the kit doctor on Windows.
setlocal
set "AGENTKIT_PS=pwsh"
where /q pwsh || set "AGENTKIT_PS=powershell"
"%AGENTKIT_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\lib\Invoke-AgentKit.ps1" %*
exit /b %ERRORLEVEL%
