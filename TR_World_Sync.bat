@echo off
setlocal
title TR World Project - Synchroniseur Anti-Crash
color 0B

echo =======================================================================
echo          TR WORLD PROJECT - SYNCHRONISEUR ET ANTI-CRASH V1.0
echo =======================================================================
echo.

if exist "%~dp0scripts\sync_client.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\sync_client.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $code = (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/EnriqueP01/tr-world-project-sync/main/scripts/sync_client.ps1'); Invoke-Expression $code"
)

echo.
echo =======================================================================
echo   Operation terminee. Appuyez sur une touche pour quitter...
echo =======================================================================
pause >nul
