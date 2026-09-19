@echo off
rem agentbox - the machines command on Windows (stdlib Python, shared with Unix).
setlocal
set "AGENTKIT_PS=pwsh"
where /q pwsh || set "AGENTKIT_PS=powershell"
"%AGENTKIT_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\lib\Invoke-AgentBox.ps1" %*
exit /b %ERRORLEVEL%
