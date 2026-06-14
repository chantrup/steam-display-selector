@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: STEAM DISPLAY PICKER
:: ============================================================
::
:: WHAT THIS SCRIPT DOES:
::   When you click Play on a Steam game, this script runs first,
::   asks you which monitor to launch on, edits the game's config
::   file to set that monitor, then launches the game. The game's
::   renderer initializes on the correct monitor from the start.
::
:: HOW TO ADD A NEW GAME (3 steps):
::
::   STEP 1 - Find the game's config file and monitor field.
::     Every game stores display settings differently. You need:
::       a) The full path to the config file on your PC
::       b) The name of the monitor/display field inside that file
::       c) Which FILETYPE the game uses (see options below)
::
::     To find the config file: search Google for:
::       "[Game Name] config file location monitor AppData Windows"
::     Then open the file in Notepad and look for a field that
::     controls which monitor/display the game launches on.
::
::   STEP 2 - Add lines to the GAME REGISTRY section below.
::     Copy an existing game block and change the values.
::     The KEY is a short name you make up (no spaces).
::
::     There are three FILETYPE options depending on the game:
::
::     --- FILETYPE: plain ---
::     For plain text configs where the field is just a number.
::     Example: fullscreen_output = 0
::     Requires: CONFIG, FIELD, FILETYPE
::     Monitor values are 0-based: Monitor 1=0, 2=1, 3=2, 4=3
::
::       set CONFIG_MYKEY=C:\Users\YourName\AppData\Roaming\...\settings.cfg
::       set FIELD_MYKEY=monitor_field_name
::       set FILETYPE_MYKEY=plain
::
::     --- FILETYPE: utf16 ---
::     For UTF-16 encoded XML configs where the field is a number.
::     Example: <OutputMonitor>0</OutputMonitor>
::     Requires: CONFIG, FIELD, FILETYPE
::     Monitor values are 0-based: Monitor 1=0, 2=1, 3=2, 4=3
::     How to tell if a file is UTF-16: open it in Notepad. If it
::     looks garbled or scrambled -> utf16. If readable -> plain.
::
::       set CONFIG_MYKEY=C:\Users\YourName\AppData\Roaming\...\Config.xml
::       set FIELD_MYKEY=MonitorFieldName
::       set FILETYPE_MYKEY=utf16
::
::     --- FILETYPE: string-multi-field ---
::     For RE Engine games (Capcom) where one or more fields need
::     to be swapped when changing monitors.
::     Each monitor gets one TARGET line containing ALL fields to
::     update, separated by semicolons, in FIELD=VALUE format.
::     Example with one field:
::       set TARGET_MYKEY_1=DisplayName=XB271HU
::     Example with multiple fields:
::       set TARGET_MYKEY_1=DisplayName=XB271HU;NormalWindowResolution=(2560^,1440)
::     Note: commas inside values must be escaped with ^ (e.g. (2560^,1440))
::     Note: the float version of NormalWindowResolution uses a different
::           regex pattern - see MHWILDS example below for reference.
::
::     To find your monitor values: open the game, go to display
::     settings, switch to each monitor, quit, open config.ini,
::     and note what fields changed for each monitor.
::
::       set CONFIG_MYKEY=C:\...\config.ini
::       set FILETYPE_MYKEY=string-multi-field
::       set TARGET_MYKEY_1=Field1=Value1;Field2=Value2
::       set TARGET_MYKEY_3=Field1=Value1;Field2=Value2
::     (Only add TARGET lines for monitors you actually use)
::
::   STEP 3 - Set the Steam Launch Option for that game to:
::       "C:\Path\To\SteamDisplayPicker.bat" MYKEY %command%
::     Replace MYKEY with whatever KEY you used in Step 2.
::     (Right-click game in Steam -> Properties -> Launch Options)
::
:: ============================================================


:: ============================================================
:: MONITOR LABELS
:: Change these to match how you identify your monitors.
:: These are only used for display in the picker prompt.
:: ============================================================

set LABEL_1=Monitor 1 (Main)
set LABEL_2=Monitor 2
set LABEL_3=Monitor 3 (usual swap)
set LABEL_4=Monitor 4


:: ============================================================
:: GAME REGISTRY
:: Add new games here following the instructions above.
:: ============================================================

:: --- Helldivers 2 ---
:: Steam Launch Option: "C:\Path\To\SteamDisplayPicker.bat" HD2 %command%
set CONFIG_HD2=%APPDATA%\Arrowhead\Helldivers2\user_settings.config
set FIELD_HD2=fullscreen_output
set FILETYPE_HD2=plain

:: --- Elden Ring Nightreign ---
:: Steam Launch Option: "C:\Path\To\SteamDisplayPicker.bat" NIGHTREIGN %command%
set CONFIG_NIGHTREIGN=%APPDATA%\Nightreign\GraphicsConfig.xml
set FIELD_NIGHTREIGN=OutputMonitor
set FILETYPE_NIGHTREIGN=utf16

:: --- Monster Hunter Wilds ---
:: Steam Launch Option: "C:\Path\To\SteamDisplayPicker.bat" MHWILDS %command%
:: Multiple fields are separated by semicolons.
:: Commas inside values must be escaped with ^ (e.g. (2560^,1440))
set CONFIG_MHWILDS=D:\SteamLibrary\steamapps\common\MonsterHunterWilds\config.ini
set FILETYPE_MHWILDS=string-multi-field
set TARGET_MHWILDS_1=DisplayName=XB271HU;FullScreenDisplayModeIndex=464;FullScreenDisplayMode=464;NormalWindowResolution=(2560^,1440);NormalWindowResolution_float=(2560.000000^,1440.000000)
set TARGET_MHWILDS_3=DisplayName=Q70A;FullScreenDisplayModeIndex=201;FullScreenDisplayMode=201;NormalWindowResolution=(2560^,1440);NormalWindowResolution_float=(2560.000000^,1440.000000)

:: --- Pragmata ---
:: Steam Launch Option: "C:\Path\To\SteamDisplayPicker.bat" PRAGMATA %command%
set CONFIG_PRAGMATA=D:\SteamLibrary\steamapps\common\PRAGMATA\config.ini
set FILETYPE_PRAGMATA=string-multi-field
set TARGET_PRAGMATA_1=TargetDisplay=1:XB271HU
set TARGET_PRAGMATA_3=TargetDisplay=3:Q70A

:: --- ADD NEW GAMES BELOW THIS LINE ---
:: Copy one of the blocks above, change the KEY and values, done.


:: ============================================================
:: SCRIPT LOGIC - no need to edit anything below this line
:: ============================================================

:: Read game key from first argument, rebuild game launch command from the rest
set GAME_KEY=%1
shift

set GAME_CMD=%1
:argloop
shift
if "%1"=="" goto argdone
set GAME_CMD=!GAME_CMD! %1
goto argloop
:argdone

if not defined GAME_KEY (
    echo.
    echo  ERROR: No game key provided.
    echo  Steam Launch Option should be:
    echo  "C:\Path\To\SteamDisplayPicker.bat" [GAME_KEY] %%command%%
    echo.
    pause
    exit /b 1
)

:: Look up config path, field, and file type for this game key
set CONFIG=!CONFIG_%GAME_KEY%!
set FIELD=!FIELD_%GAME_KEY%!
set FILETYPE=!FILETYPE_%GAME_KEY%!

if not defined CONFIG (
    echo.
    echo  ERROR: No config path found for game key "%GAME_KEY%".
    echo  Add it to the GAME REGISTRY section at the top of this script.
    echo.
    pause
    exit /b 1
)

if not defined FILETYPE (
    echo.
    echo  ERROR: No filetype found for game key "%GAME_KEY%".
    echo  Add it to the GAME REGISTRY section at the top of this script.
    echo.
    pause
    exit /b 1
)

:: Show monitor picker
echo.
echo  ==========================================
echo   STEAM DISPLAY PICKER - %GAME_KEY%
echo  ==========================================
echo.
echo   [1]  %LABEL_1%
echo   [2]  %LABEL_2%
echo   [3]  %LABEL_3%
echo   [4]  %LABEL_4%
echo   [Enter]  Keep current config unchanged
echo.
set /p CHOICE=" Enter monitor number (1-4) or Enter to skip: "

:: If Enter was pressed with no input, skip config edit and launch immediately
if "!CHOICE!"=="" (
    echo.
    echo  Skipping config update, launching %GAME_KEY% as-is...
    echo.
    goto launch
)

:: Validate choice
if "!CHOICE!"=="1" goto valid
if "!CHOICE!"=="2" goto valid
if "!CHOICE!"=="3" goto valid
if "!CHOICE!"=="4" goto valid
echo.
echo  Invalid choice. Defaulting to Monitor 1.
set CHOICE=1
:valid

:: Set 0-based index for plain/utf16 types
set MONITOR_INDEX=0
if "!CHOICE!"=="2" set MONITOR_INDEX=1
if "!CHOICE!"=="3" set MONITOR_INDEX=2
if "!CHOICE!"=="4" set MONITOR_INDEX=3

:: Edit the config file using the correct method for the file type
if /i "!FILETYPE!"=="plain" (
    powershell -Command "(Get-Content '!CONFIG!') -replace '!FIELD! = \d+', '!FIELD! = !MONITOR_INDEX!' | Set-Content '!CONFIG!'"
    goto launch
)

if /i "!FILETYPE!"=="utf16" (
    powershell -Command "$content = Get-Content '!CONFIG!' -Encoding Unicode -Raw; $content = $content -replace '<![FIELD!]>\d+</![FIELD!]>', '<![FIELD!]>!MONITOR_INDEX!</![FIELD!]>'; Set-Content '!CONFIG!' -Value $content -Encoding Unicode -NoNewline"
    goto launch
)

if /i "!FILETYPE!"=="string-multi-field" (
    set TARGET=!TARGET_%GAME_KEY%_%CHOICE%!
    if not defined TARGET (
        echo.
        echo  ERROR: No TARGET defined for %GAME_KEY% Monitor !CHOICE!.
        echo  Add "set TARGET_%GAME_KEY%_!CHOICE!=Field=Value" to the GAME REGISTRY.
        echo.
        pause
        exit /b 1
    )

    :: Split TARGET on semicolons and apply each FIELD=VALUE pair
    set PS_COMMANDS=
    for /f "tokens=1* delims=;" %%A in ("!TARGET!") do (
        call :apply_field "%%A" "!CONFIG!"
        if not "%%B"=="" (
            set REMAINING=%%B
            call :process_remaining "!CONFIG!"
        )
    )
    goto launch
)

echo.
echo  ERROR: Unknown FILETYPE "!FILETYPE!" for game "%GAME_KEY%".
echo  Valid options are: plain, utf16, string-multi-field
echo.
pause
exit /b 1

:: Subroutine to apply a single FIELD=VALUE pair to the config
:apply_field
set PAIR=%~1
set CFGFILE=%~2
:: Split on first = to get field name and value
for /f "tokens=1* delims==" %%F in ("!PAIR!") do (
    set F_NAME=%%F
    set F_VALUE=%%G
)
:: Special handling for NormalWindowResolution float format in RenderConfig
if "!F_NAME!"=="NormalWindowResolution_float" (
    powershell -Command "(Get-Content '!CFGFILE!') -replace 'NormalWindowResolution=\(\d+\.\d+,\d+\.\d+\)', 'NormalWindowResolution=(!F_VALUE!)' | Set-Content '!CFGFILE!'"
) else (
    powershell -Command "(Get-Content '!CFGFILE!') -replace '!F_NAME!=.*', '!F_NAME!=!F_VALUE!' | Set-Content '!CFGFILE!'"
)
goto :eof

:: Subroutine to process remaining semicolon-delimited pairs
:process_remaining
for /f "tokens=1* delims=;" %%A in ("!REMAINING!") do (
    call :apply_field "%%A" "%~1"
    if not "%%B"=="" (
        set REMAINING=%%B
        call :process_remaining "%~1"
    )
)
goto :eof

:launch
echo.
echo  Launching %GAME_KEY% on Monitor %CHOICE%...
echo.

:: Launch the game detached so this window closes immediately after handoff
start "" !GAME_CMD!

endlocal
