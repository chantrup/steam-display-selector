:: ============================================================
:: GAME REGISTRY
:: ============================================================
:: This file holds the per-game settings for Steam Display Selector.
:: Add new games here following the instructions in SteamDisplaySelector.bat.
:: This file is loaded automatically - you never need to touch the
:: main .bat file to add or edit a game.
:: ============================================================

:: --- Helldivers 2 ---
:: Steam Launch Option: "C:\Path\To\SteamDisplaySelector.bat" HD2 %command%
set CONFIG_HD2=%APPDATA%\Arrowhead\Helldivers2\user_settings.config
set FIELD_HD2=fullscreen_output
set FILETYPE_HD2=plain

:: --- Elden Ring Nightreign ---
:: Steam Launch Option: "C:\Path\To\SteamDisplaySelector.bat" NIGHTREIGN %command%
set CONFIG_NIGHTREIGN=%APPDATA%\Nightreign\GraphicsConfig.xml
set FIELD_NIGHTREIGN=OutputMonitor
set FILETYPE_NIGHTREIGN=utf16

:: --- Monster Hunter Wilds ---
:: Steam Launch Option: "C:\Path\To\SteamDisplaySelector.bat" MHWILDS %command%
:: Multiple fields are separated by semicolons.
:: Commas inside values must be escaped with ^ (e.g. (2560^,1440))
set CONFIG_MHWILDS=D:\SteamLibrary\steamapps\common\MonsterHunterWilds\config.ini
set FILETYPE_MHWILDS=string-multi-field
set TARGET_MHWILDS_1=DisplayName=XB271HU;FullScreenDisplayModeIndex=464;FullScreenDisplayMode=464;NormalWindowResolution=(2560^,1440);NormalWindowResolution_float=(2560.000000^,1440.000000)
set TARGET_MHWILDS_3=DisplayName=Q70A;FullScreenDisplayModeIndex=201;FullScreenDisplayMode=201;NormalWindowResolution=(2560^,1440);NormalWindowResolution_float=(2560.000000^,1440.000000)

:: --- Pragmata ---
:: Steam Launch Option: "C:\Path\To\SteamDisplaySelector.bat" PRAGMATA %command%
set CONFIG_PRAGMATA=D:\SteamLibrary\steamapps\common\PRAGMATA\config.ini
set FILETYPE_PRAGMATA=string-multi-field
set TARGET_PRAGMATA_1=TargetDisplay=1:XB271HU
set TARGET_PRAGMATA_3=TargetDisplay=3:Q70A

:: --- Crimson Desert ---
:: Steam Launch Option: "C:\Path\To\SteamDisplaySelector.bat" CRIMSONDESERT %command%
:: This game DELETES its _display field entirely when set to the
:: default/primary monitor, so Monitor 1 uses DELETE instead of a value.
:: Requires xmlfield.ps1 in the same folder (field name starts with _).
set CONFIG_CRIMSONDESERT=%LOCALAPPDATA%\Pearl Abyss\CD\save\user_engine_option_save.xml
set FILETYPE_CRIMSONDESERT=string-multi-field
set TARGET_CRIMSONDESERT_1=_display=DELETE
set TARGET_CRIMSONDESERT_3=_display=Q70A 0

:: --- ADD NEW GAMES BELOW THIS LINE ---
:: Copy one of the blocks above, change the KEY and values, done.
