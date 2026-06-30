@echo off
:: ============================================================
::  STEAM DISPLAY SELECTOR - launcher
:: ============================================================
::  Steam runs .bat files cleanly as a launch option, and this
::  wrapper sets the PowerShell execution policy for this one
::  call so users never have to change machine-wide settings.
::
::  Steam Launch Option for a game:
::    "C:\Path\To\SteamDisplaySelector.bat" GAMEKEY %command%
::
::  Add new games with:  powershell -ExecutionPolicy Bypass -File "%~dp0Add-Game.ps1"
:: ============================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0engine\SteamDisplaySelector.ps1" %*
