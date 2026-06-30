<#
===============================================================================
 ADD-GAME  (auto-learn wizard for Steam Display Selector v2)
===============================================================================
 You never hand-write a config rule. You just:

   1. Tell the wizard the game's config-file path.
   2. In-game, set the display to a monitor, fully quit, press Enter.
   3. Repeat for each monitor you care about.

 The wizard compares the snapshots, figures out exactly which line(s) the game
 changes for each monitor (including lines it deletes entirely), and writes a
 profile into gameslist.json. The engine then reproduces those lines on demand.

 Run from a normal PowerShell window:
   powershell -ExecutionPolicy Bypass -File .\Add-Game.ps1
===============================================================================
#>

$ErrorActionPreference = 'Stop'
$ABSENT = '__ABSENT__'

# ---- same encoding-aware reader as the engine ------------------------------
function Read-Lines([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) { $text = [System.Text.Encoding]::Unicode.GetString($bytes) }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) { $text = [System.Text.Encoding]::BigEndianUnicode.GetString($bytes) }
    else { $text = (New-Object System.Text.UTF8Encoding($false)).GetString($bytes) }
    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
    $norm = $text -replace "`r`n", "`n"
    $lines = @($norm -split "`n")
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '' -and $text.EndsWith("`n")) {
        $lines = $lines[0..($lines.Count - 2)]
    }
    return ,$lines
}

function Common-Prefix([string]$a, [string]$b) {
    $n = 0; $m = [Math]::Min($a.Length, $b.Length)
    while ($n -lt $m -and $a[$n] -eq $b[$n]) { $n++ }
    return $a.Substring(0, $n)
}
function Common-Suffix([string]$a, [string]$b) {
    $n = 0; $m = [Math]::Min($a.Length, $b.Length)
    while ($n -lt $m -and $a[$a.Length - 1 - $n] -eq $b[$b.Length - 1 - $n]) { $n++ }
    if ($n -eq 0) { return '' }
    return $a.Substring($a.Length - $n)
}

# ---- enumerated-table detection ---------------------------------------------
# Games sometimes dump an entire capability table (every display mode the GPU
# reports, every resolution available) into the config, and it gets rewritten
# whenever the active monitor changes - not because each line is a deliberate
# per-monitor setting, but because the whole table gets regenerated. These
# show up as hundreds of fields sharing a near-identical name template
# (DisplayMode100_Height, DisplayMode101_Height, ...). The fix is structural,
# not keyword-based, so it catches the pattern regardless of whether the
# varying token is numeric (...100...) or not (...AA..., ...AB...).
#
# Pass 1 (fast, O(n)): collapse every digit run to '#' and bucket by the
# result. Catches the common numeric-table case in one pass with no per-pair
# comparison at all.
function Get-DigitSignature([string]$s) {
    return [regex]::Replace($s, '\d+', '#')
}

# Pass 2 (careful, only on what's left): two names are "the same template,
# different middle" if they share most of their length as a common prefix +
# suffix, with only a short dissimilar middle section in between. This is the
# same shape whether that middle is "100"/"101" or "AA"/"AB" - no character-
# class assumption baked in.
function Test-Similar([string]$a, [string]$b) {
    $pre = (Common-Prefix $a $b).Length
    $suf = (Common-Suffix $a $b).Length
    $shorter = [Math]::Min($a.Length, $b.Length)
    if ($shorter -eq 0) { return $false }
    if (($pre + $suf) -gt $shorter) { $suf = $shorter - $pre }
    $overlap = $pre + $suf
    $midA = $a.Length - $pre - $suf
    $midB = $b.Length - $pre - $suf
    return (($overlap / $shorter) -ge 0.7) -and ($midA -le 6) -and ($midB -le 6)
}

function Find-ClusterRoot($parent, $x) {
    while ($parent[$x] -ne $x) { $parent[$x] = $parent[$parent[$x]]; $x = $parent[$x] }
    return $x
}

# Returns an array (same length/order as $samples): each entry is either a
# cluster-id string (this field belongs to a table-sized group) or $null
# (this field is a standalone candidate worth showing individually).
function Get-TableClusterIds($samples, [int]$threshold) {
    $n = $samples.Count
    $clusterId = @($null) * $n
    $nextId = 0

    # Pass 1: bucket by digit-collapsed signature.
    $buckets = @{}
    for ($i = 0; $i -lt $n; $i++) {
        $sig = Get-DigitSignature $samples[$i]
        if (-not $buckets.ContainsKey($sig)) { $buckets[$sig] = New-Object System.Collections.ArrayList }
        [void]$buckets[$sig].Add($i)
    }
    $residual = New-Object System.Collections.ArrayList
    foreach ($sig in $buckets.Keys) {
        $idxs = $buckets[$sig]
        if ($idxs.Count -ge $threshold) {
            $id = "P1-$nextId"; $nextId++
            foreach ($idx in $idxs) { $clusterId[$idx] = $id }
        } else {
            foreach ($idx in $idxs) { [void]$residual.Add($idx) }
        }
    }

    # Pass 2: pairwise structural similarity, but only on the (always small)
    # residual that Pass 1 didn't already resolve.
    $parent = @{}
    foreach ($idx in $residual) { $parent[$idx] = $idx }
    for ($a = 0; $a -lt $residual.Count; $a++) {
        for ($b = $a + 1; $b -lt $residual.Count; $b++) {
            $ia = $residual[$a]; $ib = $residual[$b]
            if (Test-Similar $samples[$ia] $samples[$ib]) {
                $ra = Find-ClusterRoot $parent $ia
                $rb = Find-ClusterRoot $parent $ib
                if ($ra -ne $rb) { $parent[$ra] = $rb }
            }
        }
    }
    $groups2 = @{}
    foreach ($idx in $residual) {
        $root = Find-ClusterRoot $parent $idx
        if (-not $groups2.ContainsKey($root)) { $groups2[$root] = New-Object System.Collections.ArrayList }
        [void]$groups2[$root].Add($idx)
    }
    foreach ($root in $groups2.Keys) {
        $idxs = $groups2[$root]
        if ($idxs.Count -ge $threshold) {
            $id = "P2-$nextId"; $nextId++
            foreach ($idx in $idxs) { $clusterId[$idx] = $id }
        }
    }

    return $clusterId
}

# A singleton field that shares a big cluster's leading "stem" (e.g. a stray
# DisplayModeCount sitting next to 700 DisplayModeNN_* lines) is almost
# certainly part of the same table conceptually, even though it didn't
# structurally cluster with anything on its own.
function Get-Stem([string]$s) {
    $m = [regex]::Match($s.TrimStart('<'), '^([A-Za-z_]{4,})')
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Anchor-For($lines, [string]$target) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq $target -and $i -gt 0) { return $lines[$i - 1] }
    }
    return $null
}

# ---- native file picker, with the result converted back to a portable %TOKEN% path -----
function ConvertTo-PortablePath([string]$path) {
    $map = [ordered]@{
        '%LOCALAPPDATA%'       = $env:LOCALAPPDATA
        '%APPDATA%'            = $env:APPDATA
        '%PROGRAMFILES(X86)%'  = ${env:ProgramFiles(x86)}
        '%PROGRAMFILES%'       = $env:ProgramFiles
        '%USERPROFILE%'        = $env:USERPROFILE
    }
    foreach ($token in $map.Keys) {
        $val = $map[$token]
        if ($val -and $path.StartsWith($val, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $token + $path.Substring($val.Length)
        }
    }
    return $path
}

function Select-ConfigFile {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = "Select the game's display config file"
        $dialog.Filter = "All files (*.*)|*.*"
        $dialog.InitialDirectory = $env:APPDATA
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return (ConvertTo-PortablePath $dialog.FileName)
        }
        return $null
    } catch {
        Write-Host "  Couldn't open a file picker in this environment ($($_.Exception.Message))." -ForegroundColor Yellow
        return $null
    }
}

# ---- key validation: only letters, digits, underscore, hyphen - no spaces or
# symbols, since the key has to survive being passed through Steam's Launch
# Option field (which splits on spaces) and Windows batch files (where % is a
# special character). Retries instead of silently sanitizing what was typed.
function Read-ValidKey([string]$Prompt) {
    while ($true) {
        $k = (Read-Host $Prompt).Trim()
        if ($k -match '^[A-Za-z0-9_-]+$') { return $k }
        Write-Host "  Keys can only use letters, numbers, underscore, and hyphen - no spaces" -ForegroundColor Yellow
        Write-Host "  or symbols (these break Steam's Launch Option field). Examples: HD2," -ForegroundColor Yellow
        Write-Host "  MHWILDS, CRIMSONDESERT, MY-COOL-GAME, my_game_2" -ForegroundColor Yellow
    }
}

# ---- core diff: learn the fields that distinguish monitor A from monitor B --
function Capture-Pair($linesA, [string]$monA, $linesB, [string]$monB) {
    $countB = @{}; foreach ($l in $linesB) { $countB[$l] = ($countB[$l] + 1) }
    $countA = @{}; foreach ($l in $linesA) { $countA[$l] = ($countA[$l] + 1) }
    $onlyA = @($linesA | Where-Object { -not $countB.ContainsKey($_) })
    $onlyB = @($linesB | Where-Object { -not $countA.ContainsKey($_) })

    $fields = New-Object System.Collections.ArrayList
    $usedB = @($false) * $onlyB.Count
    $pairedA = @{}

    # pair changed-value lines by best prefix+suffix overlap (greedy 1:1)
    foreach ($a in $onlyA) {
        $bestScore = -1; $bestIdx = -1
        for ($j = 0; $j -lt $onlyB.Count; $j++) {
            if ($usedB[$j]) { continue }
            $score = (Common-Prefix $a $onlyB[$j]).Length + (Common-Suffix $a $onlyB[$j]).Length
            if ($score -gt $bestScore) { $bestScore = $score; $bestIdx = $j }
        }
        if ($bestIdx -ge 0 -and $bestScore -gt 0) {
            $b = $onlyB[$bestIdx]; $usedB[$bestIdx] = $true; $pairedA[$a] = $true
            $pre = Common-Prefix $a $b
            $suf = Common-Suffix $a $b
            if (($pre.Length + $suf.Length) -gt [Math]::Min($a.Length, $b.Length)) { $suf = '' }
            $lines = [ordered]@{}; $lines[$monA] = $a; $lines[$monB] = $b
            [void]$fields.Add([pscustomobject]@{
                desc    = if ([string]::IsNullOrWhiteSpace($pre)) { 'field' } else { $pre.Trim() }
                locator = [pscustomobject]@{ kind = 'wrap'; prefix = $pre; suffix = $suf }
                anchor  = $null
                lines   = $lines
            })
        }
    }

    # leftover onlyA = present on A, absent on B
    foreach ($a in $onlyA) {
        if ($pairedA.ContainsKey($a)) { continue }
        $lines = [ordered]@{}; $lines[$monA] = $a; $lines[$monB] = $ABSENT
        [void]$fields.Add([pscustomobject]@{
            desc    = "$($a.Trim()) (present/absent)"
            locator = [pscustomobject]@{ kind = 'exact'; text = $a.Trim() }
            anchor  = (Anchor-For $linesA $a)
            lines   = $lines
        })
    }
    # leftover onlyB = present on B, absent on A
    for ($j = 0; $j -lt $onlyB.Count; $j++) {
        if ($usedB[$j]) { continue }
        $b = $onlyB[$j]
        $lines = [ordered]@{}; $lines[$monA] = $ABSENT; $lines[$monB] = $b
        [void]$fields.Add([pscustomobject]@{
            desc    = "$($b.Trim()) (present/absent)"
            locator = [pscustomobject]@{ kind = 'exact'; text = $b.Trim() }
            anchor  = (Anchor-For $linesB $b)
            lines   = $lines
        })
    }
    return $fields
}

function Merge-Fields($into, $new) {
    foreach ($nf in $new) {
        $match = $null
        foreach ($ef in $into) {
            if (($ef.locator | ConvertTo-Json -Compress) -eq ($nf.locator | ConvertTo-Json -Compress)) { $match = $ef; break }
        }
        if ($match) {
            foreach ($p in $nf.lines.GetEnumerator()) { $match.lines[$p.Key] = $p.Value }
            if (-not $match.anchor -and $nf.anchor) { $match.anchor = $nf.anchor }
        } else {
            [void]$into.Add($nf)
        }
    }
}

# ============================================================================
# WIZARD
# ============================================================================
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "   ADD A GAME  -  Steam Display Selector"
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir   # this script lives in engine/; gameslist.json lives one level up
$jsonPath  = Join-Path $rootDir 'gameslist.json'
$existingCfg = $null
if (Test-Path -LiteralPath $jsonPath) {
    $existingCfg = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
}

$key  = Read-ValidKey "  Short key for this game (letters/numbers/underscore/hyphen only, e.g. HD2)"

if ($existingCfg -and $existingCfg.games.PSObject.Properties[$key]) {
    $existingName = $existingCfg.games.$key.name
    Write-Host ""
    Write-Host "  WARNING: key '$key' already exists ('$existingName')." -ForegroundColor Yellow
    $overwrite = (Read-Host "  Overwrite it? Type yes to confirm, or anything else to pick a different key").Trim().ToLower()
    if ($overwrite -ne 'yes') {
        $key = Read-ValidKey "  New short key for this game"
        if ($existingCfg.games.PSObject.Properties[$key]) {
            Write-Host "  '$key' also already exists. Aborting - rerun and pick a free key." -ForegroundColor Red
            exit 1
        }
    }
}

$name = (Read-Host "  Display name (e.g. Helldivers 2)").Trim()
Write-Host ""
Write-Host "  Paste the FULL path to the game's display config file, or press Enter"
Write-Host "  to open a file picker instead."
Write-Host "  (You may use %APPDATA% / %LOCALAPPDATA% etc; they'll be kept as-is for portability.)"
$cfgRaw = (Read-Host "  Config path").Trim('"').Trim()
if ([string]::IsNullOrWhiteSpace($cfgRaw)) {
    Write-Host "  Opening file picker..."
    $picked = Select-ConfigFile
    if ($picked) {
        $cfgRaw = $picked
        Write-Host "  Selected: $cfgRaw" -ForegroundColor Green
    } else {
        $cfgRaw = (Read-Host "  No file selected. Paste the path manually").Trim('"').Trim()
    }
}
$cfgExpanded = [System.Environment]::ExpandEnvironmentVariables($cfgRaw)
if (-not (Test-Path -LiteralPath $cfgExpanded)) {
    Write-Host "  WARNING: that path doesn't exist yet. Make sure the game has been launched once so the file exists." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  You'll now capture one snapshot per monitor. For each one:"
Write-Host "    - In the GAME's display settings, set it to that monitor."
Write-Host "    - FULLY QUIT the game (so it writes the config)."
Write-Host "    - Come back here and press Enter."
Write-Host "  Tip: change ONLY the monitor between captures. Other changes (resolution,"
Write-Host "  quality settings) will get picked up as if they were monitor-related."

$retryCapture = $true
while ($retryCapture) {
    $retryCapture = $false
    Write-Host ""

    $snapshots = @{}   # monitorNumber -> lines
    while ($true) {
        $mon = (Read-Host "  Monitor number you are about to capture (1-4), or 'done'").Trim()
        if ($mon -eq 'done') { break }
        if ($mon -notin '1','2','3','4') { Write-Host "  Enter 1, 2, 3, 4, or done." -ForegroundColor Yellow; continue }
        Read-Host "  Set the game to Monitor $mon, quit it, then press Enter to snapshot" | Out-Null
        if (-not (Test-Path -LiteralPath $cfgExpanded)) { Write-Host "  Config still not found; skipping." -ForegroundColor Yellow; continue }
        $snapshots[$mon] = Read-Lines $cfgExpanded
        Write-Host "  Captured Monitor $mon  ($($snapshots[$mon].Count) lines)." -ForegroundColor Green
    }

    if ($snapshots.Count -lt 2) { Write-Host ""; Write-Host "  Need at least two monitors to learn anything. Aborting." -ForegroundColor Red; exit 1 }

    # learn: diff each captured monitor against the first one, then fold together
    $mons = @($snapshots.Keys | Sort-Object)
    $base = $mons[0]
    $fields = New-Object System.Collections.ArrayList
    foreach ($m in $mons) {
        if ($m -eq $base) { continue }
        $pair = Capture-Pair $snapshots[$base] $base $snapshots[$m] $m
        Merge-Fields $fields $pair
    }

    # noise guard
    Write-Host ""
    Write-Host "  Detected the following monitor-controlled line(s):" -ForegroundColor Cyan

    if ($fields.Count -eq 0) { Write-Host "  Nothing changed between snapshots - did the monitor setting actually change? Aborting." -ForegroundColor Red; exit 1 }

    # ---- step 1: extract a clean sample + present/absent status per field,
    # with nothing printed yet - table detection needs to see the whole set
    # at once before any line gets displayed.
    $samples = @($null) * $fields.Count
    $isPA    = @($false) * $fields.Count
    for ($i = 0; $i -lt $fields.Count; $i++) {
        $f = $fields[$i]
        $realValue = $f.lines.Values | Where-Object { $_ -ne $ABSENT } | Select-Object -First 1
        $isPA[$i] = [bool]($f.lines.Values | Where-Object { $_ -eq $ABSENT })
        $samples[$i] = if ($realValue) { "$realValue".Trim() } else { $ABSENT }
    }

    # ---- step 2: structural table clustering (see Get-TableClusterIds above) --
    $clusterId = Get-TableClusterIds $samples 4

    # ---- step 3: stem-association sweep - catch a stray singleton like
    # DisplayModeCount sitting next to 700 DisplayModeNN_* lines. This is a
    # prefix test, not exact equality: DisplayModeCount's own leading-letters
    # stem is "DisplayModeCount" (no digit to stop the match), which never
    # equals the cluster's stem "DisplayMode" - but it does start with it.
    $stemCounts = @{}
    for ($i = 0; $i -lt $fields.Count; $i++) {
        if ($clusterId[$i]) {
            $stem = Get-Stem $samples[$i]
            if ($stem) { $stemCounts[$stem] = ([int]$stemCounts[$stem] + 1) }
        }
    }
    $bigStems = @()
    foreach ($s in $stemCounts.Keys) { if ($stemCounts[$s] -ge 4) { $bigStems += $s } }

    # ---- step 4: classify every field, printing standalone candidates as we
    # go and silently tallying table-noise fields for a summary afterward.
    $flagList = New-Object System.Collections.ArrayList
    $tableExamples = @{}      # group key -> @{ Hits = N; Example = "..." }
    $totalSuppressed = 0
    for ($i = 0; $i -lt $fields.Count; $i++) {
        $sample = $samples[$i]
        $flag = ''
        $suppressKey = $null

        $matchedStem = $bigStems | Where-Object { $sample.StartsWith($_) } | Select-Object -First 1
        if ($clusterId[$i]) {
            $flag = 'table'; $suppressKey = "cluster:$($clusterId[$i])"
        } elseif ($matchedStem) {
            $flag = 'table'; $suppressKey = "stem:$matchedStem"
        } elseif ($isPA[$i] -and ($sample -match '(?i)display|monitor|screen|output')) {
            $flag = 'display'
        } elseif ($isPA[$i]) {
            $flag = 'present-absent'
        } elseif ($sample -match '\.\d{5,}') {
            $flag = 'noise'
        } elseif ($sample -match '(?i)display|monitor|screen|output') {
            $flag = 'display'
        }
        [void]$flagList.Add($flag)

        if ($flag -eq 'table') {
            if (-not $tableExamples.ContainsKey($suppressKey)) {
                $tableExamples[$suppressKey] = @{ Hits = 0; Example = $sample }
            }
            $tableExamples[$suppressKey].Hits = $tableExamples[$suppressKey].Hits + 1
            $totalSuppressed++
            continue   # don't print table-noise lines individually
        }

        $tag = switch ($flag) {
            'display'        { if ($isPA[$i]) { '[present/absent, looks display-related] ' } else { '[looks display-related] ' } }
            'present-absent' { '[present/absent - review]    ' }
            'noise'          { '[likely noise]           ' }
            default          { '' }
        }
        Write-Host ("   {0}. {1}{2}" -f ($i + 1), $tag, $sample)
    }

    if ($tableExamples.Count -gt 0) {
        Write-Host ""
        Write-Host "  Auto-suppressed $totalSuppressed field(s) that looked like an auto-generated" -ForegroundColor DarkGray
        Write-Host "  table (e.g. a list of every display mode the GPU reports) - not shown" -ForegroundColor DarkGray
        Write-Host "  individually since these are essentially never the real monitor setting:" -ForegroundColor DarkGray
        $shown = 0
        foreach ($key in $tableExamples.Keys) {
            if ($shown -ge 6) {
                Write-Host "    ... and $($tableExamples.Count - $shown) more group(s) like this" -ForegroundColor DarkGray
                break
            }
            $info = $tableExamples[$key]
            Write-Host ("    - {0} field(s) like: {1}" -f $info.Hits, $info.Example) -ForegroundColor DarkGray
            $shown++
        }
    }

    $shownCount = $fields.Count - $totalSuppressed
    if ($shownCount -gt 6) {
        Write-Host ""
        Write-Host "  NOTE: that's still several changed lines after filtering. Lines marked" -ForegroundColor Yellow
        Write-Host "  '[likely noise]' are auto-tuned values (VRS, shadow quality, etc.) rather" -ForegroundColor Yellow
        Write-Host "  than monitor settings. Lines marked '[looks display-related]' are your" -ForegroundColor Yellow
        Write-Host "  best candidates." -ForegroundColor Yellow
    }

    # ---- recommendation: draw only from fields that survived the table
    # filter, ranked by keyword match if any non-table candidate matched one.
    $candidateIdx = @()
    $displayIdx = @()
    for ($k = 0; $k -lt $flagList.Count; $k++) {
        if ($flagList[$k] -eq 'table') { continue }
        $candidateIdx += ($k + 1)
        if ($flagList[$k] -eq 'display') { $displayIdx += ($k + 1) }
    }
    if ($displayIdx.Count -eq 0) { $displayIdx = $candidateIdx }

    Write-Host ""
    if ($displayIdx.Count -gt 0 -and $displayIdx.Count -lt $fields.Count) {
        Write-Host "  Recommendation: k $($displayIdx -join ',')" -ForegroundColor Green
        Write-Host "  (keeps only the field(s) that survived auto-filtering above - review before using)"
        Write-Host "  Type 'r' to apply this recommendation directly."
    } elseif ($displayIdx.Count -eq 0) {
        Write-Host "  Nothing was auto-flagged as display-related - review the list manually before pruning." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  To prune: type 'x' followed by numbers to EXCLUDE, or 'k' followed by numbers"
    Write-Host "  to KEEP ONLY those (e.g. 'x 2,4,5' or 'k 1,6')."
    while ($true) {
        $prune = (Read-Host "  Your choice, or press Enter to keep all").Trim().Trim("'").Trim('"')
        if ([string]::IsNullOrWhiteSpace($prune)) { break }   # keep all, proceed to save prompt

        $mode = $null; $numsRaw = $null
        if ($prune -match '^[Rr]$') {
            if ($displayIdx.Count -eq 0) {
                Write-Host "  No recommendation available - nothing was auto-flagged as display-related." -ForegroundColor Yellow
                continue
            }
            $mode = 'k'; $numsRaw = ($displayIdx -join ',')
        }
        elseif ($prune -match '^([XxKk])\s*(.*)$') { $mode = $Matches[1].ToLower(); $numsRaw = $Matches[2].Trim() }
        elseif ($prune -match '^[\d,\s]+$') { $mode = 'x'; $numsRaw = $prune }

        if (-not $mode -or [string]::IsNullOrWhiteSpace($numsRaw) -or ($numsRaw -notmatch '^[\d,\s]+$')) {
            Write-Host "  Didn't understand '$prune'. Use 'x 2,4,5', 'k 1,6', 'r' for the recommendation, or press Enter to keep all." -ForegroundColor Yellow
            continue
        }

        $nums = $numsRaw -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
        if ($nums.Count -eq 0) {
            Write-Host "  No valid numbers found in '$prune'. Try again, or press Enter to keep all." -ForegroundColor Yellow
            continue
        }
        $badNums = @($nums | Where-Object { $_ -lt 1 -or $_ -gt $fields.Count })
        if ($badNums.Count -gt 0) {
            Write-Host "  Number(s) out of range (valid: 1-$($fields.Count)): $($badNums -join ', '). Try again." -ForegroundColor Yellow
            continue
        }

        $kept = New-Object System.Collections.ArrayList
        for ($idx = 0; $idx -lt $fields.Count; $idx++) {
            $n = $idx + 1
            $isListed = $n -in $nums
            $keepThis = if ($mode -eq 'k') { $isListed } else { -not $isListed }
            if ($keepThis) { [void]$kept.Add($fields[$idx]) }
        }
        $removedCount = $fields.Count - $kept.Count
        $fields = $kept
        Write-Host "  Removed $removedCount field(s). $($fields.Count) remaining." -ForegroundColor Green
        if ($fields.Count -eq 0) { Write-Host "  Nothing left to save. Aborting." -ForegroundColor Red; exit 1 }
        break
    }
    Write-Host ""
    Write-Host "  About to save $($fields.Count) field(s):" -ForegroundColor Cyan
    $i = 1
    foreach ($f in $fields) {
        Write-Host "   $i. $($f.desc)"
        foreach ($p in ($f.lines.GetEnumerator() | Sort-Object Key)) {
            $val = if ($p.Value -eq $ABSENT) { '(removed on this monitor)' } else { $p.Value }
            Write-Host "      Monitor $($p.Key): $val"
        }
        $i++
    }
    Write-Host ""
    $go = (Read-Host "  Save this profile to gameslist.json? Type 'y' to save, 'r' to recapture the monitors, or anything else to cancel").Trim().ToLower()
    if ($go -eq 'r') {
        Write-Host ""
        Write-Host "  Recapturing - your previous snapshots for this game are discarded." -ForegroundColor Yellow
        $retryCapture = $true
        continue
    }
    if ($go -ne 'y') { Write-Host "  Cancelled. Nothing written." ; exit 0 }
}

# ---- write into gameslist.json -------------------------------------------------
if ($existingCfg) {
    $cfg = $existingCfg
} else {
    $cfg = [pscustomobject]@{
        monitorLabels = [pscustomobject]@{ '1' = 'Monitor 1 (Main)'; '2' = 'Monitor 2'; '3' = 'Monitor 3 (usual swap)'; '4' = 'Monitor 4' }
        games         = [pscustomobject]@{}
    }
}

$gameObj = [pscustomobject]@{ name = $name; config = $cfgRaw; fields = $fields }
$cfg.games | Add-Member -NotePropertyName $key -NotePropertyValue $gameObj -Force

($cfg | ConvertTo-Json -Depth 12) | Set-Content -LiteralPath $jsonPath -Encoding UTF8

Write-Host ""
Write-Host "  Saved '$key' to gameslist.json." -ForegroundColor Green
Write-Host "  Steam Launch Option for this game:" -ForegroundColor Cyan
Write-Host "    `"$rootDir\SteamDisplaySelector.bat`" $key %command%"
Write-Host ""
