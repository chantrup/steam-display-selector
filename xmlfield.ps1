param(
    [Parameter(Mandatory=$true)][string]$ConfigFile,
    [Parameter(Mandatory=$true)][string]$FieldName,
    [Parameter(Mandatory=$true)][string]$FieldValue,
    [Parameter(Mandatory=$false)][string]$AnchorTag = '<EngineOptionResolution Name="_resolutionOption">'
)

# xmlfield.ps1
# Edits a single self-closing <OptionStringVector Name="X" _value="Y"/> style
# line inside an XML config file used by Steam Display Selector.
#
# Behavior:
#   - DELETE   -> removes the line entirely if it exists. No-op if absent.
#   - any value -> if the field's line already exists, replaces its value.
#                  if it does not exist, inserts a new line directly after
#                  the given $AnchorTag (defaults to the EngineOptionResolution
#                  opening tag used by Crimson Desert's config).
#
# This file is intentionally plain PowerShell with no batch-file escaping
# involved, since batch's handling of < > and nested quotes proved too
# fragile for this kind of XML editing.

if (-not (Test-Path $ConfigFile)) {
    Write-Host "ERROR: Config file not found: $ConfigFile"
    exit 1
}

$content = Get-Content -Path $ConfigFile

$openTag  = '<OptionStringVector Name="'
$midTag   = '" _value="'
$closeTag = '"/>'

$pattern = [regex]::Escape($openTag) + [regex]::Escape($FieldName) + [regex]::Escape($midTag) + '[^"]*' + [regex]::Escape($closeTag)

$matchFound = $false
foreach ($line in $content) {
    if ($line -match $pattern) {
        $matchFound = $true
        break
    }
}

if ($FieldValue -eq 'DELETE') {
    if ($matchFound) {
        $newContent = $content | Where-Object { $_ -notmatch $pattern }
        Set-Content -Path $ConfigFile -Value $newContent
        Write-Host "Removed field '$FieldName' from config."
    } else {
        Write-Host "Field '$FieldName' was already absent. No change needed."
    }
    exit 0
}

if ($matchFound) {
    $replacement = $openTag + $FieldName + $midTag + $FieldValue + $closeTag
    $newContent = $content -replace $pattern, $replacement
    Set-Content -Path $ConfigFile -Value $newContent
    Write-Host "Updated field '$FieldName' to '$FieldValue'."
} else {
    $anchorFound = $false
    foreach ($line in $content) {
        if ($line -match [regex]::Escape($AnchorTag)) {
            $anchorFound = $true
            break
        }
    }
    if (-not $anchorFound) {
        Write-Host "ERROR: Could not find anchor tag to insert new field. No changes made."
        exit 1
    }
    $newLine = "            " + $openTag + $FieldName + $midTag + $FieldValue + $closeTag
    $newContent = $content -replace [regex]::Escape($AnchorTag), ($AnchorTag + "`r`n" + $newLine)
    Set-Content -Path $ConfigFile -Value $newContent
    Write-Host "Inserted new field '$FieldName' with value '$FieldValue'."
}
