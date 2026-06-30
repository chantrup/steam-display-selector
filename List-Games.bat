@echo off
:: ============================================================
::  LIST GAMES - launcher
:: ============================================================
::  Double-click this file to see every game currently stored in
::  gameslist.json, and optionally remove one, without needing to
::  open PowerShell yourself or change any system-wide execution
::  policy. The bypass below only applies to this one run.
:: ============================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine\List-Games.ps1"

echo.
pause
