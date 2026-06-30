<#
===============================================================================
 STEAM DISPLAY SELECTOR  (v2 engine)
===============================================================================
 ONE mechanism handles every game:

   A game profile is just "which lines in the config change when you switch
   monitors, and what each of those lines looks like for each monitor."
   Applying a monitor = find that line, swap it for the target monitor's
   version of the line. "Absent" is a valid version, which is how a field
   that gets deleted on the primary monitor (e.g. Crimson Desert) is handled.

 There is NO per-game code below. Encoding (UTF-8 / UTF-16 / BOM), XML vs INI,
 single vs multiple fields, and delete-the-field-entirely all collapse into the
 same find-and-swap operation. New games are added as DATA in gameslist.json,
 normally generated for you by Add-Game.ps1 (the auto-learn wizard).

 Steam Launch Option (via the .bat wrapper, recommended):
   "C:\Path\To\SteamDisplaySelector.bat" GAMEKEY %command%
===============================================================================
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$GameKey,

    # Everything after the key is the game's real launch command from Steam's
    # %command% token: the exe path followed by any launch flags.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$LaunchCommand
)

$ErrorActionPreference = 'Stop'
$ABSENT = '__ABSENT__'

function Fail($msg) {
    Write-Host ""
    Write-Host "  ERROR: $msg" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Press Enter to exit"
    exit 1
}

# ----------------------------------------------------------------------------
# Encoding-aware read that records BOM + line-ending style so we can write the
# file back faithfully (games are picky about both).
# ----------------------------------------------------------------------------
function Read-Config([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { Fail "Config file not found: $Path" }
    $bytes = [System.IO.File]::ReadAllBytes($Path)

    $enc = 'utf8'; $bom = $false
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $enc = 'utf16le'; $bom = $true }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { $enc = 'utf16be'; $bom = $true }
    elseif ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $enc = 'utf8'; $bom = $true }

    switch ($enc) {
        'utf16le' { $text = [System.Text.Encoding]::Unicode.GetString($bytes) }
        'utf16be' { $text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes) }
        default   { $text = (New-Object System.Text.UTF8Encoding($false)).GetString($bytes) }
    }
    # The Unicode/BigEndianUnicode/UTF8(BOM) decoders leave the BOM as a leading
    # U+FEFF char; strip it so we don't double-write it later.
    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }

    $eol = if ($text -match "`r`n") { "`r`n" } else { "`n" }
    $trailing = $text.EndsWith("`n")
    $norm = $text -replace "`r`n", "`n"
    $lines = [System.Collections.Generic.List[string]]@($norm -split "`n")
    if ($trailing -and $lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') { $lines.RemoveAt($lines.Count - 1) }

    return [pscustomobject]@{ Lines = $lines; Enc = $enc; Bom = $bom; Eol = $eol; Trailing = $trailing }
}

function Write-Config([string]$Path, $Meta) {
    $body = ($Meta.Lines -join $Meta.Eol)
    if ($Meta.Trailing) { $body += $Meta.Eol }
    switch ($Meta.Enc) {
        'utf16le' {
            $payload = [System.Text.Encoding]::Unicode.GetBytes($body)
            $out = if ($Meta.Bom) { ,([byte]0xFF) + [byte]0xFE + $payload } else { $payload }
        }
        'utf16be' {
            $payload = [System.Text.Encoding]::BigEndianUnicode.GetBytes($body)
            $out = if ($Meta.Bom) { ,([byte]0xFE) + [byte]0xFF + $payload } else { $payload }
        }
        default {
            $u8 = New-Object System.Text.UTF8Encoding($Meta.Bom)   # $true => emit BOM
            $out = $u8.GetBytes($body)
        }
    }
    [System.IO.File]::WriteAllBytes($Path, $out)
}

# ----------------------------------------------------------------------------
# Locate the line a field controls, no matter which monitor it's currently set
# to. 'wrap' matches by an invariant prefix+suffix; 'exact' matches a whole
# (trimmed) line for present/absent fields.
# ----------------------------------------------------------------------------
function Find-LineIndex($Lines, $Field) {
    $loc = $Field.locator
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $ln = $Lines[$i]
        if ($loc.kind -eq 'wrap') {
            if ($ln.StartsWith($loc.prefix) -and $ln.EndsWith($loc.suffix)) { return $i }
        }
        elseif ($loc.kind -eq 'exact') {
            if ($ln.Trim() -eq $loc.text) { return $i }
        }
    }
    return -1
}

function Has-Monitor($Field, $Mon) {
    return ($null -ne $Field.lines.PSObject.Properties[$Mon])
}

# ----------------------------------------------------------------------------
# Apply one monitor choice to the config.
# ----------------------------------------------------------------------------
function Apply-Profile([string]$Path, $Game, [string]$Mon) {
    $meta  = Read-Config $Path
    $lines = $meta.Lines

    foreach ($field in $Game.fields) {
        if (-not (Has-Monitor $field $Mon)) { continue }   # not captured for this monitor: leave alone
        $target = $field.lines.$Mon
        $idx = Find-LineIndex $lines $field

        if ($target -eq $ABSENT) {
            if ($idx -ge 0) { $lines.RemoveAt($idx) }
        }
        elseif ($idx -ge 0) {
            $lines[$idx] = $target
        }
        else {
            # Field is absent but should be present: insert after its anchor.
            $ai = -1
            if ($field.PSObject.Properties['anchor'] -and $field.anchor) {
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i].Trim() -eq ([string]$field.anchor).Trim()) { $ai = $i; break }
                }
            }
            if ($ai -ge 0) { $lines.Insert($ai + 1, $target) }
            else { $lines.Add($target) }   # best effort
        }
    }

    $meta.Lines = $lines
    Write-Config $Path $meta
}

# ============================================================================
# MAIN
# ============================================================================
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir   # this script lives in engine/; gameslist.json lives one level up
$jsonPath  = Join-Path $rootDir 'gameslist.json'
if (-not (Test-Path -LiteralPath $jsonPath)) { Fail "gameslist.json not found in $rootDir. Run Add-Game.bat to create it." }

$cfg = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json

$game = $cfg.games.PSObject.Properties[$GameKey].Value
if ($null -eq $game) { Fail "No game with key '$GameKey' in gameslist.json. Run Add-Game.ps1 to add it." }

$configPath = [System.Environment]::ExpandEnvironmentVariables($game.config)

# ---- recent monitor history (last 2 picks per game) -----------------------
# Unlike gameslist.json, this is internal bookkeeping you never need to open -
# it lives alongside the engine scripts, not at the top level with your data.
$historyPath = Join-Path $scriptDir 'history.json'
$history = $null
if (Test-Path -LiteralPath $historyPath) {
    try { $history = Get-Content -LiteralPath $historyPath -Raw | ConvertFrom-Json } catch { $history = $null }
}
if ($null -eq $history) { $history = [pscustomobject]@{} }
# @() guards against PowerShell 5.1 unwrapping a single-element JSON array into
# a bare scalar - the same bug class we hit in the monitor-profile lookup.
$recentMons = if ($history.PSObject.Properties[$GameKey]) { @($history.$GameKey) } else { @() }

# ---- monitor picker -------------------------------------------------------
$labels = $cfg.monitorLabels
function Get-MonLabel([string]$n) {
    if ($labels.PSObject.Properties[$n]) { return $labels.$n } else { return "Monitor $n" }
}
Write-Host ""
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host "   STEAM DISPLAY SELECTOR - $GameKey ($($game.name))"
Write-Host "  ==========================================" -ForegroundColor Cyan
Write-Host ""
if ($recentMons.Count -gt 0) {
    Write-Host "  Last used: $(Get-MonLabel $recentMons[0])" -ForegroundColor DarkGray
    if ($recentMons.Count -gt 1) {
        Write-Host "  Before that: $(Get-MonLabel $recentMons[1])" -ForegroundColor DarkGray
    }
    Write-Host ""
}
foreach ($n in '1','2','3','4') {
    Write-Host "   [$n]  $(Get-MonLabel $n)"
}
Write-Host "   [Enter]  Keep current config unchanged"
Write-Host ""

# Loop until the user reaches a resolved outcome (valid pick, or explicit skip).
# An invalid number or an uncaptured monitor sends them straight back to the
# prompt - nothing launches until they land on something that actually works.
$choice = $null
while ($true) {
    $choice = Read-Host "  Enter monitor number (1-4) or Enter to skip"

    if ([string]::IsNullOrWhiteSpace($choice)) {
        Write-Host ""
        Write-Host "  Skipping config update; launching $GameKey as-is..."
        break
    }
    elseif ($choice -notin '1','2','3','4') {
        Write-Host ""
        Write-Host "  Invalid choice - enter 1, 2, 3, 4, or press Enter to skip." -ForegroundColor Yellow
        continue
    }
    elseif (-not (@($game.fields | Where-Object { Has-Monitor $_ $choice })).Count) {
        Write-Host ""
        Write-Host "  This game has no profile for Monitor $choice yet." -ForegroundColor Yellow
        Write-Host "  Pick a different monitor, or run Add-Game.ps1 later to capture this one."
        continue
    }
    else {
        try {
            Apply-Profile $configPath $game $choice
            Write-Host ""
            Write-Host "  Set $GameKey to Monitor $choice." -ForegroundColor Green
            break
        }
        catch {
            Write-Host ""
            Write-Host "  WARNING: could not update config ($($_.Exception.Message))." -ForegroundColor Yellow
            $retry = (Read-Host "  Try a different monitor? (y/n)").Trim().ToLower()
            if ($retry -eq 'y') { continue }
            Write-Host "  Launching unchanged."
            break
        }
    }
}

# ---- record this pick for next time (best-effort, never blocks launch) ----
if ($choice -in '1','2','3','4') {
    try {
        $newHistory = @($choice) + $recentMons | Select-Object -First 2
        $history | Add-Member -NotePropertyName $GameKey -NotePropertyValue $newHistory -Force
        ($history | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $historyPath -Encoding UTF8
    } catch {
        # History is a convenience feature only - a failure here must never block the launch.
    }
}

# ---- launch ---------------------------------------------------------------
if (-not $LaunchCommand -or $LaunchCommand.Count -eq 0) {
    Write-Host ""
    Write-Host "  (No launch command passed; nothing to start. This is normal when testing outside Steam.)"
    exit 0
}

$exe  = $LaunchCommand[0]
$rest = if ($LaunchCommand.Count -gt 1) { $LaunchCommand[1..($LaunchCommand.Count - 1)] } else { @() }

Write-Host ""
Write-Host "  Launching $GameKey..."
if ($rest.Count -gt 0) { Start-Process -FilePath $exe -ArgumentList $rest }
else { Start-Process -FilePath $exe }
