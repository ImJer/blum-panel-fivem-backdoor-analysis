#requires -Version 5.1
<#
BLUM PANEL WINDOWS REMEDIATION SCRIPT v1

Windows Server 2019 / Windows PowerShell 5.1 compatible remediation helper for
known Blum Panel / Warden Panel / GFX Panel FiveM backdoor artifacts.

Default mode is dry-run. Add -Apply to make changes.

Usage:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\remediate_windows.ps1 -Path C:\FXServer\server-data
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\remediate_windows.ps1 -Path C:\FXServer\server-data -Apply

Recommended flow:
  1. Stop the FiveM server process.
  2. Run this script without -Apply and review the plan.
  3. Run again with -Apply if the planned changes are correct.
  4. Restore txAdmin files from official sources if the script reports tampering.
  5. Rotate txAdmin, RCON, database, SSH/RDP, FTP/SFTP, and Discord bot credentials.

What -Apply does:
  - Creates a timestamped quarantine directory.
  - Moves high- and medium-confidence malicious or suspicious JS/Lua files into quarantine.
  - Backs up edited files before changes.
  - Removes manifest lines that reference quarantined files.
  - Removes the known helpEmptyCode and onServerResourceFail txAdmin event blocks.
  - Optionally restores txAdmin monitor files from official GitHub raw URLs.
  - Optionally runs block_c2_windows.ps1 -Apply.

What it does not do:
  - It does not permanently delete files.
  - It does not edit txAdmin admin JSON files automatically.
  - It does not prove the server is fully clean after compromise.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = ".",

    [switch]$Apply,

    [string]$QuarantineDir = "",

    [switch]$SkipManifestCleanup,

    [switch]$SkipTxAdminCleanup,

    [switch]$RestoreTxAdminOfficial,

    [switch]$BlockC2,

    [int]$MaxFileMB = 30,

    [int]$MaxHits = 250,

    [switch]$Json
)

$ErrorActionPreference = "SilentlyContinue"

try {
    $Root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path.TrimEnd([char[]]@("\", "/"))
} catch {
    [Console]::Error.WriteLine("Remediation path not found: $Path")
    exit 3
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TimeStamp = Get-Date -Format "yyyyMMdd-HHmmss"
if ([string]::IsNullOrWhiteSpace($QuarantineDir)) {
    $QuarantineDir = Join-Path $Root "_blum_quarantine_$TimeStamp"
}

$MaxBytes = [int64]$MaxFileMB * 1024 * 1024
$Actions = New-Object System.Collections.Generic.List[object]
$QuarantineItems = New-Object System.Collections.Generic.List[object]
$ManifestEdits = New-Object System.Collections.Generic.List[object]
$TxAdminEdits = New-Object System.Collections.Generic.List[object]
$Warnings = New-Object System.Collections.Generic.List[string]
$Utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
$SelfScriptNames = @(
    "scan_windows.ps1",
    "block_c2_windows.ps1",
    "remediate_windows.ps1"
)

$C2Pattern = "(?i)(9ns1\.com|fivems\.lt|blum-panel\.me|blum-panel\.com|warden-panel\.me|jking\.lt|0xchitado\.com|2312321321321213\.com|2ns3\.net|5mscripts\.net|bhlool\.com|bybonvieux\.com|fivemgtax\.com|flowleakz\.org|giithub\.net|iwantaticket\.org|kutingplays\.com|l00x\.org|monloox\.com|noanimeisgay\.com|ryenz\.net|spacedev\.fr|trezz\.org|z1lly\.org|2nit32\.com|useer\.it\.com|wsichkidolu\.com|cipher-panel\.me|ciphercheats\.com|keyx\.club|dark-utilities\.xyz|gfxpanel\.org)"
$LoaderPattern = "(?i)(eval\s*\(|new\s+Function\s*\(|runInThisContext|https\.get|https\.request|PerformHttpRequest|LoadResourceFile|SaveResourceFile)"
$XorPattern = "String\.fromCharCode\s*\(\s*[A-Za-z0-9_$]+\s*\[\s*[A-Za-z0-9_$]+\s*\]\s*\^\s*[A-Za-z0-9_$]+\s*\)"
$LuraphPattern = "(?i)(Luraph Obfuscator|installed_notices|devJJ|nullJJ|zXeAHJJ|roleplayJJ|cityJJ|mafiaJJ|gangJJ|anonJJ|panelJJ|blumJJ|miaussJJ)"
$MediumMarkerPattern = "(?i)(decompressFromUTF16|\\u15E1|aga\[0x|UARZT6\[|Luraph Obfuscator|installed_notices|vm'\)\.runInThisContext|devJJ|nullJJ|zXeAHJJ|roleplayJJ|cityJJ|mafiaJJ|gangJJ|anonJJ|panelJJ|blumJJ|miaussJJ)"

$DropperNames = @(
    "babel_config.js",
    "jest_mock.js",
    "mock_data.js",
    "webpack_bundle.js",
    "env_backup.js",
    "cache_old.js",
    "build_cache.js",
    "vite_temp.js",
    "eslint_rc.js",
    "jest_setup.js",
    "test_utils.js",
    "utils_lib.js",
    "helper_functions.js",
    "sync_worker.js",
    "queue_handler.js",
    "session_store.js",
    "hook_system.js",
    "patch_update.js",
    "runtime_module.js",
    "stable_core.js",
    "latest_utils.js",
    "vite_plugin.js",
    "babel_preset.js",
    "database.js",
    "events.js",
    "commands.js",
    "functions.js"
)

function Write-Step {
    param([string]$Message)
    if (-not $Json) {
        Write-Host ""
        Write-Host $Message -ForegroundColor Cyan
    }
}

function Write-Info {
    param([string]$Message, [string]$Color = "Gray")
    if (-not $Json) {
        Write-Host "  $Message" -ForegroundColor $Color
    }
}

function Add-Action {
    param(
        [string]$Type,
        [string]$Target,
        [string]$Reason,
        [string]$Result = "Planned"
    )
    $Actions.Add([pscustomobject]@{
        type   = $Type
        target = $Target
        reason = $Reason
        result = $Result
    }) | Out-Null
}

function Add-Warning {
    param([string]$Message)
    $Warnings.Add($Message) | Out-Null
    Write-Info $Message "Yellow"
}

function Get-RelativePathCompat {
    param([string]$BasePath, [string]$FullPath)
    $Base = $BasePath.TrimEnd([char[]]@("\", "/"))
    if ($FullPath.StartsWith($Base, [StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath.Substring($Base.Length).TrimStart([char[]]@("\", "/"))
    }
    return (Split-Path -Leaf $FullPath)
}

function Convert-ToSafeRelativePath {
    param([string]$RelativePath)
    $Safe = $RelativePath -replace ":", "_"
    $Safe = $Safe.TrimStart([char[]]@("\", "/"))
    return $Safe
}

function Test-IsUnderPath {
    param([string]$ParentPath, [string]$ChildPath)
    $Parent = $ParentPath.TrimEnd([char[]]@("\", "/"))
    return $ChildPath.StartsWith($Parent + "\", [StringComparison]::OrdinalIgnoreCase) -or
        $ChildPath.StartsWith($Parent + "/", [StringComparison]::OrdinalIgnoreCase) -or
        $ChildPath.Equals($Parent, [StringComparison]::OrdinalIgnoreCase)
}

function Write-LinesUtf8NoBom {
    param(
        [string]$FilePath,
        [string[]]$Lines
    )
    [System.IO.File]::WriteAllLines($FilePath, $Lines, $Utf8NoBom)
}

function Backup-File {
    param([string]$FilePath)
    $Relative = Get-RelativePathCompat -BasePath $Root -FullPath $FilePath
    $SafeRelative = Convert-ToSafeRelativePath -RelativePath $Relative
    $BackupPath = Join-Path (Join-Path $QuarantineDir "backups") $SafeRelative
    if ($Apply) {
        $BackupParent = Split-Path -Parent $BackupPath
        if (-not (Test-Path -LiteralPath $BackupParent)) {
            New-Item -ItemType Directory -Path $BackupParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $FilePath -Destination $BackupPath -Force -ErrorAction Stop
    }
    return $BackupPath
}

function Read-TextRaw {
    param([string]$FilePath)
    try {
        return [System.IO.File]::ReadAllText($FilePath)
    } catch {
        return $null
    }
}

function Test-TextCandidate {
    param([System.IO.FileInfo]$File)
    if ($File.Length -gt $MaxBytes) { return $false }
    $Name = $File.Name.ToLowerInvariant()
    $Ext = $File.Extension.ToLowerInvariant()
    if ($Name -in @("fxmanifest.lua", "__resource.lua", "server.cfg", "resources.cfg")) { return $true }
    if ($Ext -in @(".js", ".lua", ".cfg", ".json", ".txt", ".html")) { return $true }
    return $false
}

function Add-QuarantineCandidate {
    param(
        [System.IO.FileInfo]$File,
        [string]$Reason,
        [ValidateSet("High", "Medium")]
        [string]$Severity = "High"
    )
    if ($QuarantineItems.Count -ge $MaxHits) { return }
    $Existing = $QuarantineItems | Where-Object { $_.path -ieq $File.FullName } | Select-Object -First 1
    if ($Existing) { return }

    $Relative = Get-RelativePathCompat -BasePath $Root -FullPath $File.FullName
    $QuarantineItems.Add([pscustomobject]@{
        path       = $File.FullName
        relative   = $Relative
        severity   = $Severity
        reason     = $Reason
        size_bytes = [int64]$File.Length
    }) | Out-Null
}

function Remove-EventBlock {
    param(
        [string[]]$Lines,
        [string]$MarkerPattern
    )

    $Out = New-Object System.Collections.Generic.List[string]
    $Removed = 0
    $I = 0
    while ($I -lt $Lines.Count) {
        if ($Lines[$I] -match $MarkerPattern) {
            if ($Out.Count -gt 0 -and $Out[$Out.Count - 1] -match "^\s*--") {
                $Out.RemoveAt($Out.Count - 1)
                $Removed++
            }

            while ($I -lt $Lines.Count) {
                $Removed++
                $Line = $Lines[$I]
                $I++
                if ($Line -match "^\s*end\)\s*$") {
                    break
                }
            }
            continue
        }

        $Out.Add($Lines[$I]) | Out-Null
        $I++
    }

    return [pscustomobject]@{
        lines   = $Out.ToArray()
        removed = $Removed
    }
}

function Restore-TxAdminOfficialFile {
    param(
        [string]$FilePath,
        [string]$Url
    )

    Add-Action -Type "RestoreTxAdminOfficial" -Target $FilePath -Reason $Url
    if (-not $Apply) { return }

    try {
        Backup-File -FilePath $FilePath | Out-Null
        $TempFile = Join-Path $env:TEMP ("txadmin-official-" + [Guid]::NewGuid().ToString() + ".tmp")
        Invoke-WebRequest -Uri $Url -OutFile $TempFile -UseBasicParsing -ErrorAction Stop
        Copy-Item -LiteralPath $TempFile -Destination $FilePath -Force -ErrorAction Stop
        Remove-Item -LiteralPath $TempFile -Force -ErrorAction SilentlyContinue
        $TxAdminEdits.Add([pscustomobject]@{
            path   = $FilePath
            action = "restored_official"
            source = $Url
        }) | Out-Null
    } catch {
        Add-Warning "Failed to restore official txAdmin file $FilePath`: $($_.Exception.Message)"
    }
}

if (-not $Json) {
    $Mode = "DRY RUN"
    if ($Apply) { $Mode = "APPLY" }
    Write-Host ""
    Write-Host "============================================"
    Write-Host "  BLUM PANEL WINDOWS REMEDIATION v1"
    Write-Host "============================================"
    Write-Host "  Mode: $Mode"
    Write-Host "  Path: $Root"
    Write-Host "  Quarantine: $QuarantineDir"
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
    if (-not $Apply) {
        Write-Host ""
        Write-Host "Dry run only. Re-run with -Apply to make changes." -ForegroundColor Yellow
    }
}

Write-Step "[1/6] Finding high- and medium-confidence malicious or suspicious files"
$Files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "[\\/]\.git[\\/]" -and
        $_.FullName -notmatch "[\\/]_blum_quarantine_[0-9]{8}-[0-9]{6}[\\/]" -and
        -not ($SelfScriptNames -contains $_.Name.ToLowerInvariant()) -and
        -not (Test-IsUnderPath -ParentPath $QuarantineDir -ChildPath $_.FullName) -and
        (Test-TextCandidate $_)
    })

foreach ($File in $Files) {
    $Text = Read-TextRaw -FilePath $File.FullName
    if ($null -eq $Text) { continue }

    $Ext = $File.Extension.ToLowerInvariant()
    $Name = $File.Name.ToLowerInvariant()
    $SuspiciousPath = $File.FullName -match "(?i)[\\/](server|modules|middleware|dist)[\\/]|[\\/]node_modules[\\/]\.cache[\\/]"

    if ($Ext -eq ".js" -and $Text -match $XorPattern -and $Text -match "eval\s*\(") {
        Add-QuarantineCandidate -File $File -Severity "High" -Reason "XOR JavaScript dropper with eval"
        continue
    }

    if (($Ext -eq ".js" -or $Ext -eq ".lua") -and $Text -match $C2Pattern -and $Text -match $LoaderPattern) {
        Add-QuarantineCandidate -File $File -Severity "High" -Reason "Known C2 reference with executable loader behavior"
        continue
    }

    if ($Ext -eq ".lua" -and $Text -match $LuraphPattern -and ($Text -match $C2Pattern -or $Text -match "PerformHttpRequest")) {
        Add-QuarantineCandidate -File $File -Severity "High" -Reason "Luraph or Lua loader marker with C2 behavior"
        continue
    }

    if (($DropperNames -contains $Name) -and $SuspiciousPath -and $Text -match "(?i)(fromCharCode|eval\s*\(|https\.get|PerformHttpRequest)") {
        Add-QuarantineCandidate -File $File -Severity "High" -Reason "Known dropper filename in suspicious path with loader markers"
        continue
    }

    if (($DropperNames -contains $Name) -and $SuspiciousPath) {
        Add-QuarantineCandidate -File $File -Severity "Medium" -Reason "Known dropper filename in suspicious path"
        continue
    }

    if (($Ext -eq ".js" -or $Ext -eq ".lua") -and $Text -match $MediumMarkerPattern) {
        Add-QuarantineCandidate -File $File -Severity "Medium" -Reason "Obfuscation or loader marker matched scanner Medium rule"
        continue
    }
}

if ($QuarantineItems.Count -eq 0) {
    Write-Info "No high- or medium-confidence files selected for quarantine." "Green"
} else {
    foreach ($Item in $QuarantineItems) {
        Write-Info "Quarantine planned [$($Item.severity)]: $($Item.relative) - $($Item.reason)" "Yellow"
        Add-Action -Type "Quarantine" -Target $Item.path -Reason "[$($Item.severity)] $($Item.reason)"
    }
}

Write-Step "[2/6] Quarantining malicious files"
foreach ($Item in $QuarantineItems) {
    $SafeRelative = Convert-ToSafeRelativePath -RelativePath $Item.relative
    $Destination = Join-Path (Join-Path $QuarantineDir "files") $SafeRelative

    if ($Apply) {
        try {
            $DestinationParent = Split-Path -Parent $Destination
            if (-not (Test-Path -LiteralPath $DestinationParent)) {
                New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
            }
            Move-Item -LiteralPath $Item.path -Destination $Destination -Force -ErrorAction Stop
            Write-Info "Moved to quarantine: $($Item.relative)" "Green"
        } catch {
            Add-Warning "Failed to quarantine $($Item.path): $($_.Exception.Message)"
        }
    }
}

if (-not $SkipManifestCleanup) {
    Write-Step "[3/6] Cleaning manifest references"
    $ManifestFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-IsUnderPath -ParentPath $QuarantineDir -ChildPath $_.FullName) -and
            ($_.Name -ieq "fxmanifest.lua" -or $_.Name -ieq "__resource.lua")
        })

    $DropperNamePattern = "(?i)(" + (($DropperNames | ForEach-Object { [regex]::Escape($_) }) -join "|") + ")"
    foreach ($Manifest in $ManifestFiles) {
        $OriginalLines = @(Get-Content -LiteralPath $Manifest.FullName -ErrorAction SilentlyContinue)
        if ($OriginalLines.Count -eq 0) { continue }

        $NewLines = New-Object System.Collections.Generic.List[string]
        $RemovedLines = New-Object System.Collections.Generic.List[string]
        $ManifestDir = Split-Path -Parent $Manifest.FullName

        foreach ($Line in $OriginalLines) {
            $NormalizedLine = $Line -replace "\\", "/"
            $Remove = $false

            foreach ($Item in $QuarantineItems) {
                if (-not (Test-IsUnderPath -ParentPath $ManifestDir -ChildPath $Item.path)) {
                    continue
                }
                $RelToManifest = Get-RelativePathCompat -BasePath $ManifestDir -FullPath $Item.path
                $RelForward = $RelToManifest -replace "\\", "/"
                if ($NormalizedLine -match [regex]::Escape($RelForward)) {
                    $Remove = $true
                    break
                }
            }

            if (-not $Remove -and $NormalizedLine -match "(?i)(node_modules/\.cache|middleware/|dist/|server/|modules/)" -and $NormalizedLine -match $DropperNamePattern) {
                $Remove = $true
            }

            if ($Remove) {
                $RemovedLines.Add($Line) | Out-Null
            } else {
                $NewLines.Add($Line) | Out-Null
            }
        }

        if ($RemovedLines.Count -gt 0) {
            Add-Action -Type "CleanManifest" -Target $Manifest.FullName -Reason "$($RemovedLines.Count) suspicious manifest line(s)"
            Write-Info "Manifest cleanup planned: $($Manifest.FullName) ($($RemovedLines.Count) lines)" "Yellow"
            if ($Apply) {
                try {
                    Backup-File -FilePath $Manifest.FullName | Out-Null
                    $NewLineArray = $NewLines.ToArray()
                    Write-LinesUtf8NoBom -FilePath $Manifest.FullName -Lines $NewLineArray
                    $ManifestEdits.Add([pscustomobject]@{
                        path          = $Manifest.FullName
                        removed_lines = $RemovedLines.ToArray()
                    }) | Out-Null
                    Write-Info "Cleaned manifest: $($Manifest.FullName)" "Green"
                } catch {
                    Add-Warning "Failed to clean manifest $($Manifest.FullName): $($_.Exception.Message)"
                }
            }
        }
    }
} else {
    Write-Step "[3/6] Manifest cleanup skipped"
}

if (-not $SkipTxAdminCleanup) {
    Write-Step "[4/6] Cleaning known txAdmin event backdoors"
    $MonitorFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-IsUnderPath -ParentPath $QuarantineDir -ChildPath $_.FullName) -and
            $_.FullName -match "(?i)[\\/]monitor[\\/]" -and
            $_.Name -in @("cl_playerlist.lua", "sv_resources.lua", "sv_main.lua")
        })

    foreach ($TxFile in $MonitorFiles) {
        $Text = Read-TextRaw -FilePath $TxFile.FullName
        if ($null -eq $Text) { continue }

        if ($RestoreTxAdminOfficial) {
            if ($TxFile.Name -ieq "cl_playerlist.lua") {
                Restore-TxAdminOfficialFile -FilePath $TxFile.FullName -Url "https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/cl_playerlist.lua"
                continue
            }
            if ($TxFile.Name -ieq "sv_resources.lua") {
                Restore-TxAdminOfficialFile -FilePath $TxFile.FullName -Url "https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/sv_resources.lua"
                continue
            }
            if ($TxFile.Name -ieq "sv_main.lua") {
                Restore-TxAdminOfficialFile -FilePath $TxFile.FullName -Url "https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/sv_main.lua"
                continue
            }
        }

        if ($TxFile.Name -ieq "cl_playerlist.lua" -and $Text -match "helpEmptyCode") {
            $Lines = @(Get-Content -LiteralPath $TxFile.FullName -ErrorAction SilentlyContinue)
            $Cleaned = Remove-EventBlock -Lines $Lines -MarkerPattern "helpEmptyCode"
            if ($Cleaned.removed -gt 0) {
                Add-Action -Type "CleanTxAdmin" -Target $TxFile.FullName -Reason "Removed helpEmptyCode client RCE block"
                if ($Apply) {
                    try {
                        Backup-File -FilePath $TxFile.FullName | Out-Null
                        Write-LinesUtf8NoBom -FilePath $TxFile.FullName -Lines $Cleaned.lines
                        $TxAdminEdits.Add([pscustomobject]@{
                            path          = $TxFile.FullName
                            action        = "removed_helpEmptyCode"
                            removed_lines = $Cleaned.removed
                        }) | Out-Null
                    } catch {
                        Add-Warning "Failed to clean $($TxFile.FullName): $($_.Exception.Message)"
                    }
                }
                Write-Info "txAdmin cleanup planned: $($TxFile.FullName) helpEmptyCode" "Yellow"
            }
        }

        if ($TxFile.Name -ieq "sv_resources.lua" -and $Text -match "onServerResourceFail") {
            $Lines = @(Get-Content -LiteralPath $TxFile.FullName -ErrorAction SilentlyContinue)
            $Cleaned = Remove-EventBlock -Lines $Lines -MarkerPattern "onServerResourceFail"
            if ($Cleaned.removed -gt 0) {
                Add-Action -Type "CleanTxAdmin" -Target $TxFile.FullName -Reason "Removed onServerResourceFail server RCE block"
                if ($Apply) {
                    try {
                        Backup-File -FilePath $TxFile.FullName | Out-Null
                        Write-LinesUtf8NoBom -FilePath $TxFile.FullName -Lines $Cleaned.lines
                        $TxAdminEdits.Add([pscustomobject]@{
                            path          = $TxFile.FullName
                            action        = "removed_onServerResourceFail"
                            removed_lines = $Cleaned.removed
                        }) | Out-Null
                    } catch {
                        Add-Warning "Failed to clean $($TxFile.FullName): $($_.Exception.Message)"
                    }
                }
                Write-Info "txAdmin cleanup planned: $($TxFile.FullName) onServerResourceFail" "Yellow"
            }
        }

        if ($TxFile.Name -ieq "sv_main.lua" -and $Text -match "RESOURCE_EXCLUDE|isExcludedResource") {
            Add-Warning "txAdmin sv_main.lua resource cloaking detected: $($TxFile.FullName). Use -RestoreTxAdminOfficial or restore txAdmin from an official release."
            Add-Action -Type "TxAdminManualRestoreRequired" -Target $TxFile.FullName -Reason "RESOURCE_EXCLUDE or isExcludedResource detected"
        }
    }

    $AdminJsonHits = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-IsUnderPath -ParentPath $QuarantineDir -ChildPath $_.FullName) -and
            $_.Extension -ieq ".json" -and
            ($_.Name -ieq "admins.json" -or $_.FullName -match "(?i)[\\/]txData[\\/]|[\\/]txAdmin[\\/]")
        } |
        Select-String -Pattern "(?i)JohnsUrUncle" -ErrorAction SilentlyContinue)

    foreach ($Hit in $AdminJsonHits) {
        Add-Warning "Backdoor txAdmin admin account string found in $($Hit.Path):$($Hit.LineNumber). Remove the account in txAdmin UI or edit JSON after backing it up."
        Add-Action -Type "ManualAdminRemovalRequired" -Target $Hit.Path -Reason "JohnsUrUncle"
    }
} else {
    Write-Step "[4/6] txAdmin cleanup skipped"
}

Write-Step "[5/6] Optional C2 blocking"
if ($BlockC2) {
    $BlockScript = Join-Path $ScriptDir "block_c2_windows.ps1"
    if (Test-Path -LiteralPath $BlockScript) {
        Add-Action -Type "BlockC2" -Target $BlockScript -Reason "Run Windows C2 blocker"
        if ($Apply) {
            & $BlockScript -Apply
        } else {
            & $BlockScript
        }
    } else {
        Add-Warning "block_c2_windows.ps1 not found next to this script."
    }
} else {
    Write-Info "Skipped. Re-run with -BlockC2 to preview or apply C2 blocking." "Gray"
}

Write-Step "[6/6] Summary"
$SummaryMode = "dry-run"
if ($Apply) { $SummaryMode = "apply" }
$HighQuarantineCount = @($QuarantineItems | Where-Object { $_.severity -eq "High" }).Count
$MediumQuarantineCount = @($QuarantineItems | Where-Object { $_.severity -eq "Medium" }).Count
$Summary = [pscustomobject]@{
    mode                    = $SummaryMode
    path                    = $Root
    quarantine_dir          = $QuarantineDir
    actions_planned_or_run  = $Actions.Count
    quarantine_candidates   = $QuarantineItems.Count
    high_quarantine         = $HighQuarantineCount
    medium_quarantine       = $MediumQuarantineCount
    manifest_files_changed  = $ManifestEdits.Count
    txadmin_files_changed   = $TxAdminEdits.Count
    warnings                = $Warnings.Count
}

if ($Json) {
    [pscustomobject]@{
        scanner         = "blum-panel-windows-remediation"
        version         = "1"
        generated_utc   = (Get-Date).ToUniversalTime().ToString("o")
        summary         = $Summary
        actions         = $Actions
        quarantine      = $QuarantineItems
        manifest_edits  = $ManifestEdits
        txadmin_edits   = $TxAdminEdits
        warnings        = $Warnings
    } | ConvertTo-Json -Depth 6
} else {
    Write-Host ""
    Write-Host "============================================"
    Write-Host " SUMMARY"
    Write-Host "============================================"
    Write-Host " Mode:                  $($Summary.mode)"
    Write-Host " Actions:               $($Summary.actions_planned_or_run)"
    Write-Host " Quarantine candidates: $($Summary.quarantine_candidates)"
    Write-Host " High quarantine:       $($Summary.high_quarantine)"
    Write-Host " Medium quarantine:     $($Summary.medium_quarantine)"
    Write-Host " Manifest files changed:$($Summary.manifest_files_changed)"
    Write-Host " txAdmin files changed: $($Summary.txadmin_files_changed)"
    Write-Host " Warnings:              $($Summary.warnings)"
    Write-Host " Quarantine directory:  $QuarantineDir"
    Write-Host ""
    if (-not $Apply) {
        Write-Host "Dry run complete. Re-run with -Apply after reviewing the planned actions." -ForegroundColor Yellow
    } else {
        Write-Host "Remediation actions completed. Review warnings, rotate credentials, and run scan_windows.ps1 again." -ForegroundColor Green
    }
    Write-Host "============================================"
}

if ($Warnings.Count -gt 0) { exit 1 }
exit 0
