@echo off
setlocal enabledelayedexpansion

:: ============================================================
:: STEAM DISPLAY SELECTOR
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
::   STEP 2 - Add lines to games.bat (in the same folder as this file).
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
::     For games where one or more fields need to be swapped when
::     changing monitors (common in RE Engine / Capcom games, and
::     some other engines that store display name + extra fields).
::     Each monitor gets one TARGET line containing ALL fields to
::     update, separated by semicolons, in FIELD=VALUE format.
::
::     Example with one field:
::       set TARGET_MYKEY_1=DisplayName=XB271HU
::
::     Example with multiple fields:
::       set TARGET_MYKEY_1=DisplayName=XB271HU;NormalWindowResolution=(2560^,1440)
::     Note: commas inside values must be escaped with ^ (e.g. (2560^,1440))
::     Note: the float version of NormalWindowResolution uses a different
::           regex pattern - see MHWILDS example below for reference.
::
::     Example using DELETE (for games that remove the field entirely
::     when set to their default/primary monitor, e.g. Crimson Desert):
::       set TARGET_MYKEY_1=_display=DELETE
::       set TARGET_MYKEY_3=_display=Q70A 0
::     "DELETE" as the value tells the script to remove that field's
::     line from the config entirely instead of writing a value.
::
::     IMPORTANT: fields whose name starts with an underscore (like
::     _display above) are treated as XML attribute-style fields and
::     are edited by a companion file, xmlfield.ps1, which MUST be
::     saved in the SAME FOLDER as this .bat file. Fields without a
::     leading underscore are treated as plain INI-style "Field=Value"
::     lines and do not need that companion file.
::
::     To find your monitor values: open the game, go to display
::     settings, switch to each monitor, quit, open the config file,
::     and note what fields changed for each monitor. If a field
::     disappears entirely when set to one particular monitor, use
::     DELETE for that monitor's entry.
::
::       set CONFIG_MYKEY=C:\...\config.ini
::       set FILETYPE_MYKEY=string-multi-field
::       set TARGET_MYKEY_1=Field1=Value1;Field2=Value2
::       set TARGET_MYKEY_3=Field1=Value1;Field2=Value2
::     (Only add TARGET lines for monitors you actually use)
::
::   STEP 3 - Set the Steam Launch Option for that game to:
::       "C:\Path\To\SteamDisplaySelector.bat" MYKEY %command%
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
:: All per-game settings live in games.bat, in the SAME FOLDER
:: as this script. Open games.bat to add, edit, or remove games -
:: you should never need to edit anything below this point.
:: ============================================================

if not exist "%~dp0games.bat" (
    echo.
    echo  ERROR: games.bat not found.
    echo  It must be saved in the same folder as this script:
    echo  %~dp0
    echo.
    pause
    exit /b 1
)
call "%~dp0games.bat"

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
    echo  "C:\Path\To\SteamDisplaySelector.bat" [GAME_KEY] %%command%%
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
    echo  Add it to games.bat - in the same folder as this script.
    echo.
    pause
    exit /b 1
)

if not defined FILETYPE (
    echo.
    echo  ERROR: No filetype found for game key "%GAME_KEY%".
    echo  Add it to games.bat - in the same folder as this script.
    echo.
    pause
    exit /b 1
)

:: Show monitor picker
echo.
echo  ==========================================
echo   STEAM DISPLAY SELECTOR - %GAME_KEY%
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
        echo  Add "set TARGET_%GAME_KEY%_!CHOICE!=Field=Value" to games.bat.
        echo.
        pause
        exit /b 1
    )

    :: Split TARGET on semicolons and apply each FIELD=VALUE pair
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
    goto :eof
)
:: DELETE mode - remove any line containing this field entirely (works for
:: both INI-style "Field=Value" lines and XML lines with Name="Field")
if /i "!F_VALUE!"=="DELETE" (
    powershell -Command "(Get-Content '!CFGFILE!') | Where-Object { $_ -notmatch '!F_NAME!=' -and $_ -notmatch 'Name=\"!F_NAME!\"' } | Set-Content '!CFGFILE!'"
    goto :eof
)
:: XML-style field (e.g. <OptionStringVector Name="_display" _value="Q70A 0"/>)
:: Detected by field name starting with underscore, matching this project's
:: XML-format games (e.g. Crimson Desert). Delegates to xmlfield.ps1, which
:: must live in the same folder as this script. Using a real .ps1 file with
:: proper PowerShell parameters avoids batch's fragile handling of < > and
:: nested quotes, which caused this to fail when written as an inline string.
echo !F_NAME! | findstr /b "_" >nul
if !ERRORLEVEL! EQU 0 (
    powershell -ExecutionPolicy Bypass -File "%~dp0xmlfield.ps1" -ConfigFile "!CFGFILE!" -FieldName "!F_NAME!" -FieldValue "!F_VALUE!"
    goto :eof
)
:: Standard FIELD=VALUE replace (works for INI-style "Field=Value" lines)
powershell -Command "(Get-Content '!CFGFILE!') -replace '!F_NAME!=.*', '!F_NAME!=!F_VALUE!' | Set-Content '!CFGFILE!'"
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
