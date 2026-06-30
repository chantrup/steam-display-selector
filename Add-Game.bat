@echo off
:: ============================================================
::  ADD A GAME - launcher
:: ============================================================
::  Double-click this file to run the auto-learn wizard without
::  needing to open PowerShell yourself or change any system-wide
::  execution policy. The bypass below only applies to this one
::  run; it changes nothing permanent on your machine.
:: ============================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine\Add-Game.ps1"

echo.
pause
