@echo off
rem codexx - coding-agents-setup-kit wrapper (Windows shim).
rem The logic lives in ..\lib\Invoke-Wrapper.ps1 so the Unix and Windows
rem wrappers cannot drift. -ExecutionPolicy Bypass applies to THIS script only.
setlocal
set "AGENTKIT_PS=pwsh"
where /q pwsh || set "AGENTKIT_PS=powershell"
"%AGENTKIT_PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\lib\Invoke-Wrapper.ps1" codexx %*
exit /b %ERRORLEVEL%
