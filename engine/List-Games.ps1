<#
===============================================================================
 LIST-GAMES  (index + remove tool for Steam Display Selector v2)
===============================================================================
 Shows every game currently stored in gameslist.json as a clean one-line-per-
 game index - no need to ever open the JSON file yourself to see what's added.
 Also lets you remove a game by key.

 Run from a normal PowerShell window:
   powershell -ExecutionPolicy Bypass -File .\List-Games.ps1
===============================================================================
#>

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir   # this script lives in engine/; gameslist.json lives one level up
$jsonPath  = Join-Path $rootDir 'gameslist.json'

if (-not (Test-Path -LiteralPath $jsonPath)) {
    Write-Host ""
    Write-Host "  No gameslist.json found yet. Run Add-Game.ps1 to add your first game." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

$cfg = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
$keys = @($cfg.games.PSObject.Properties.Name)

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "   GAMES IN gameslist.json"
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

if ($keys.Count -eq 0) {
    Write-Host "  (none yet - run Add-Game.ps1 to add one)"
    Write-Host ""
    exit 0
}

# ---- print a clean index: key | name | config path | monitors captured ----
$rows = foreach ($key in $keys | Sort-Object) {
    $g = $cfg.games.$key
    $mons = @{}
    foreach ($field in $g.fields) {
        foreach ($p in $field.lines.PSObject.Properties) { $mons[$p.Name] = $true }
    }
    $monList = ($mons.Keys | Sort-Object) -join ', '
    [pscustomobject]@{
        Key      = $key
        Name     = $g.name
        Monitors = $monList
        Fields   = @($g.fields).Count
        Config   = $g.config
    }
}
$rows | Format-Table Key, Name, Monitors, Fields, Config -AutoSize | Out-Host

Write-Host "  Steam Launch Option format:"
Write-Host '    "C:\Path\To\SteamDisplaySelector.bat" KEY %command%'
Write-Host ""

# ---- optional remove flow --------------------------------------------------
$doRemove = (Read-Host "  Remove a game? Enter its key, or press Enter to skip").Trim()
if ([string]::IsNullOrWhiteSpace($doRemove)) { exit 0 }

if (-not $cfg.games.PSObject.Properties[$doRemove]) {
    Write-Host ""
    Write-Host "  No game with key '$doRemove'. Nothing removed." -ForegroundColor Yellow
    exit 0
}

$confirm = (Read-Host "  Remove '$doRemove' ($($cfg.games.$doRemove.name))? Type yes to confirm").Trim().ToLower()
if ($confirm -ne 'yes') {
    Write-Host "  Cancelled. Nothing removed."
    exit 0
}

$cfg.games.PSObject.Properties.Remove($doRemove)
($cfg | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

Write-Host ""
Write-Host "  Removed '$doRemove' from gameslist.json." -ForegroundColor Green
Write-Host "  Don't forget to clear that game's Steam Launch Option if you no longer want it running through this tool."
Write-Host ""
