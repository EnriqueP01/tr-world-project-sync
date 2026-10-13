@echo off
title TR World Project - Synchroniseur Anti-Crash
color 0B
powershell.exe -NoProfile -File "%~dp0scripts\sync_client.ps1"
echo.
pause
