#requires -Version 5.1
<#
================================================================================
  BLUM PANEL WINDOWS TOOLING v1
================================================================================
  All-in-one Windows defender for the Blum / Warden / Cipher / GFX Panel FiveM
  backdoor family. Compatible with Windows Server 2019 / Windows PowerShell 5.1.

  ACTIONS
    Scan       Read-only IOC scan of a FiveM server tree.
    Audit      Read-only Windows persistence audit (txAdmin admins, scheduled
               tasks, services, registry Run keys, WMI subscriptions, Defender
               exclusions, DNS client cache, recently-modified resources).
    Forensics  Read-only IR snapshot to a timestamped evidence folder
               (processes, TCP connections, hosts file, Windows event log
               windows, SHA256 hashes of resources, txAdmin config copy).
    Block      Hosts file + Windows Defender Firewall outbound block for known
               C2 domains and direct IPs. Dry-run by default; -Apply to write,
               -Undo to remove firewall rules.
    Remediate  Quarantine high-confidence malicious or suspicious JS/Lua files,
               clean infected fxmanifest.lua entries, detect (but do not
               auto-rewrite) txAdmin tampering, instruct manual reinstall.
               Dry-run by default; -Apply to act.
    All        Read-only triage trio (Scan + Audit + Forensics).
               Block and Remediate are intentionally NOT included in -All;
               run them explicitly after reviewing results.

  USAGE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\blum_windows.ps1 `
        -Action Scan -Path C:\FXServer\server-data

    powershell -NoProfile -ExecutionPolicy Bypass -File .\blum_windows.ps1 `
        -Action All -Path C:\FXServer\server-data -OutputDir .\evidence

    powershell -NoProfile -ExecutionPolicy Bypass -File .\blum_windows.ps1 `
        -Action Block -Apply

    powershell -NoProfile -ExecutionPolicy Bypass -File .\blum_windows.ps1 `
        -Action Remediate -Path C:\FXServer\server-data -Apply

  EXIT CODES
    0  No high or medium indicators found
    1  Only medium or low findings found
    2  High-confidence indicators found; treat the server as compromised
    3  Fatal error (path missing, required privilege missing for -Apply)

  IMPORTANT
    This script never auto-restores txAdmin files from the internet. If
    tampering is detected the operator is told to reinstall txAdmin from an
    official release matching the version they had installed.
================================================================================
#>

[CmdletBinding(DefaultParameterSetName = 'ByAction')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('Scan', 'Audit', 'Forensics', 'Block', 'Remediate', 'All')]
    [string]$Action,

    [string]$Path = '.',

    [string]$OutputDir = '',

    [switch]$Apply,

    [switch]$Undo,

    [switch]$Json,

    [string]$JsonOut = '',

    [int]$MaxFileMB = 30,

    [int]$MaxHitsPerCheck = 75,

    [switch]$NoNetwork,

    [switch]$IncludeHashes,

    [switch]$IncludeForensicsZip,

    [switch]$SkipManifestCleanup,

    [switch]$SkipTxAdminCheck
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# region IOC inventory
# ============================================================================

$Script:C2Domains = @(
    '9ns1.com',
    'fivems.lt',
    'blum-panel.me',
    'blum-panel.com',
    'warden-panel.me',
    'jking.lt',
    '0xchitado.com',
    '2312321321321213.com',
    '2ns3.net',
    '5mscripts.net',
    'bhlool.com',
    'bybonvieux.com',
    'fivemgtax.com',
    'flowleakz.org',
    'giithub.net',
    'iwantaticket.org',
    'kutingplays.com',
    'l00x.org',
    'monloox.com',
    'noanimeisgay.com',
    'ryenz.net',
    'spacedev.fr',
    'trezz.org',
    'z1lly.org',
    '2nit32.com',
    'useer.it.com',
    'wsichkidolu.com',
    'cipher-panel.me',
    'ciphercheats.com',
    'keyx.club',
    'dark-utilities.xyz',
    'gfxpanel.org'
) | Sort-Object -Unique

$Script:DirectIps = @(
    '185.87.23.198',    # Origin C2 backend (Hamburg, DE)
    '185.80.128.35',    # Stolen resource hosting (Vilnius, LT)
    '185.80.128.36',    # Staging/spare (Vilnius, LT)
    '185.80.130.168'    # GFX Panel C2 (Vilnius, LT)
)

$Script:DropperNames = @(
    'babel_config.js', 'jest_mock.js', 'mock_data.js', 'webpack_bundle.js',
    'env_backup.js', 'cache_old.js', 'build_cache.js', 'vite_temp.js',
    'eslint_rc.js', 'jest_setup.js', 'test_utils.js', 'utils_lib.js',
    'helper_functions.js', 'sync_worker.js', 'queue_handler.js', 'session_store.js',
    'hook_system.js', 'patch_update.js', 'runtime_module.js', 'stable_core.js',
    'latest_utils.js', 'vite_plugin.js', 'babel_preset.js'
) | Sort-Object -Unique

# Strict XOR loader byte-pattern, plus a generic variant for renamed locals
$Script:XorPatternRegex = 'String\.fromCharCode\s*\(\s*[A-Za-z0-9_$]+\s*\[\s*[A-Za-z0-9_$]+\s*\]\s*\^\s*[A-Za-z0-9_$]+\s*\)'

# Attacker handles, panel brand names, and the well-known operator constant.
$Script:AttackerIdRegex = '(?i)\b(bertjj|bertjjgg|bertjjcfxre|miauss|miausas|fivems\.lt|9ns1\.com|VB8mdVjrzd|blum-panel|warden-panel|cipher-panel|gfxpanel|ggWP)\b'

# Known txAdmin tamper markers: JohnsUrUncle is the backdoor admin; the rest
# are the cl_playerlist / sv_main / sv_resources injection points.
$Script:TxAdminTamperRegex = '(?i)(RESOURCE_EXCLUDE|isExcludedResource|onServerResourceFail|helpEmptyCode|JohnsUrUncle|txadmin:js_create)'

# JScrambler-style obfuscation residue and operator JJ-suffix API keys.
$Script:ObfuscationRegex = '(?i)(decompressFromUTF16|\\u15E1|aga\[0x|UARZT6\[|Luraph Obfuscator|installed_notices|vm''\)\.runInThisContext|devJJ|nullJJ|zXeAHJJ|roleplayJJ|cityJJ|mafiaJJ|gangJJ|anonJJ|panelJJ|blumJJ|miaussJJ)'

# Discord phone-home webhook IDs identified during analysis.
$Script:DiscordWebhookRegex = '(?i)(1470175544682217685|pe8DNcnZCjKPlKF24tk72R)'

# Loader behaviour markers used to upgrade Medium hits to High when paired with
# a C2 reference.
$Script:LoaderBehaviourRegex = '(?i)(eval\s*\(|new\s+Function\s*\(|runInThisContext|\bhttps\.get\b|\bhttps\.request\b|PerformHttpRequest|LoadResourceFile|SaveResourceFile)'

# Manifest-line patterns that match Blum's typical injected paths.
$Script:ManifestSuspiciousRegex = '(?i)(node_modules[\\/]\.|\.cache[\\/]|middleware[\\/]|dist[\\/].*\.js|babel_config|jest_mock|mock_data|webpack_bundle|env_backup|cache_old|build_cache|vite_temp|eslint_rc|jest_setup|sync_worker|hook_system|patch_update)'

$Script:SuspiciousResourcePathRegex = '(?i)[\\/](server|modules|middleware|dist)[\\/]|[\\/]node_modules[\\/]\.cache[\\/]'

# endregion

# ============================================================================
# region Shared state
# ============================================================================

$Script:Findings   = New-Object System.Collections.Generic.List[object]
$Script:Actions    = New-Object System.Collections.Generic.List[object]
$Script:Warnings   = New-Object System.Collections.Generic.List[string]
$Script:Quarantine = New-Object System.Collections.Generic.List[object]

$Script:Mode = 'DRY-RUN'
if ($Apply) { $Script:Mode = 'APPLY' }
elseif ($Undo) { $Script:Mode = 'UNDO' }

$Script:TimeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$Script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# UTF-8 without BOM — important for Lua/JS files; PS 5.1 default is UTF-16 LE
$Script:Utf8NoBom = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false

# Prevent the script from quarantining or hashing itself
$Script:SelfNames = @('blum_windows.ps1', 'scan_windows.ps1', 'block_c2_windows.ps1', 'remediate_windows.ps1')

# endregion

# ============================================================================
# region Helpers
# ============================================================================

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Section {
    param([string]$Message)
    if (-not $Json) {
        Write-Host ''
        Write-Host $Message -ForegroundColor Cyan
    }
}

function Write-OK {
    param([string]$Message)
    if (-not $Json) {
        Write-Host "  OK: $Message" -ForegroundColor Green
    }
}

function Write-WarnLine {
    param([string]$Message)
    if (-not $Json) {
        Write-Host "  $Message" -ForegroundColor Yellow
    }
}

function Write-InfoLine {
    param([string]$Message, [string]$Color = 'Gray')
    if (-not $Json) {
        Write-Host "  $Message" -ForegroundColor $Color
    }
}

function ConvertTo-ShortString {
    param([string]$Text, [int]$Max = 220)
    if ($null -eq $Text) { return '' }
    $value = ($Text -replace '\s+', ' ').Trim()
    if ($value.Length -gt $Max) {
        return $value.Substring(0, $Max) + '...'
    }
    return $value
}

function Add-Finding {
    param(
        [ValidateSet('High', 'Medium', 'Low')]
        [string]$Severity,
        [string]$Check,
        [string]$File = '',
        [int]$Line = 0,
        [string]$Evidence = '',
        [string]$Advice = ''
    )

    $finding = [pscustomobject]@{
        severity = $Severity
        check    = $Check
        file     = $File
        line     = $Line
        evidence = (ConvertTo-ShortString $Evidence)
        advice   = $Advice
    }
    [void]$Script:Findings.Add($finding)

    if (-not $Json) {
        $color = 'Yellow'
        if ($Severity -eq 'High')   { $color = 'Red' }
        elseif ($Severity -eq 'Low') { $color = 'DarkYellow' }

        $loc = ''
        if ($File) {
            $loc = $File
            if ($Line -gt 0) { $loc = "$File`:$Line" }
            Write-Host "  [$Severity] $Check - $loc" -ForegroundColor $color
        } else {
            Write-Host "  [$Severity] $Check" -ForegroundColor $color
        }
        if ($Evidence) {
            Write-Host "    Evidence: $(ConvertTo-ShortString $Evidence)" -ForegroundColor $color
        }
        if ($Advice) {
            Write-Host "    Advice: $Advice" -ForegroundColor $color
        }
    }
}

function Add-Action {
    param(
        [string]$Type,
        [string]$Target,
        [string]$Reason,
        [string]$Result = 'Planned'
    )
    [void]$Script:Actions.Add([pscustomobject]@{
        type   = $Type
        target = $Target
        reason = $Reason
        result = $Result
    })
}

function Add-WarningLine {
    param([string]$Message)
    [void]$Script:Warnings.Add($Message)
    Write-WarnLine $Message
}

function Test-IsTextCandidate {
    param([System.IO.FileInfo]$File, [int64]$MaxBytes)
    if ($File.Length -gt $MaxBytes) { return $false }
    $name = $File.Name.ToLowerInvariant()
    $ext  = $File.Extension.ToLowerInvariant()
    if ($name -in @('fxmanifest.lua', '__resource.lua', 'server.cfg', 'resources.cfg')) { return $true }
    if ($ext  -in @('.js', '.lua', '.cfg', '.json', '.txt', '.html')) { return $true }
    return $false
}

function Get-SafeFiles {
    param(
        [string]$RootPath,
        [int64]$MaxBytes,
        [string]$ExcludeUnder = ''
    )
    Get-ChildItem -LiteralPath $RootPath -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            -not ($Script:SelfNames -contains $_.Name.ToLowerInvariant()) -and
            (-not $ExcludeUnder -or -not $_.FullName.StartsWith($ExcludeUnder, [StringComparison]::OrdinalIgnoreCase)) -and
            (Test-IsTextCandidate -File $_ -MaxBytes $MaxBytes)
        }
}

function Get-RelativePathSafe {
    param([string]$BasePath, [string]$FullPath)
    $base = $BasePath.TrimEnd([char[]]@('\', '/'))
    if ($FullPath.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath.Substring($base.Length).TrimStart([char[]]@('\', '/'))
    }
    return (Split-Path -Leaf $FullPath)
}

function ConvertTo-SafeRelativePath {
    param([string]$RelativePath)
    $safe = $RelativePath -replace ':', '_'
    return $safe.TrimStart([char[]]@('\', '/'))
}

function Search-FilesForPattern {
    param(
        [string]$Check,
        [string]$Pattern,
        [ValidateSet('High', 'Medium', 'Low')]
        [string]$Severity,
        [System.IO.FileInfo[]]$Files,
        [string]$Advice = ''
    )

    if (-not $Files -or $Files.Count -eq 0) {
        Write-OK "$Check skipped (no candidate files)"
        return
    }

    $hitCount = 0
    $limitHit = $false
    foreach ($file in $Files) {
        if ($hitCount -ge $MaxHitsPerCheck) { $limitHit = $true; break }
        $regexMatches = Select-String -LiteralPath $file.FullName -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue
        foreach ($m in $regexMatches) {
            Add-Finding -Severity $Severity -Check $Check -File $m.Path -Line $m.LineNumber -Evidence $m.Line -Advice $Advice
            $hitCount++
            if ($hitCount -ge $MaxHitsPerCheck) { $limitHit = $true; break }
        }
    }

    if ($hitCount -eq 0) {
        Write-OK "$Check clean"
    } elseif ($limitHit) {
        Write-WarnLine "$Check hit limit reached ($MaxHitsPerCheck). There may be more matches."
    }
}

function Test-IsHostsBlockedDomain {
    param([string]$HostsText, [string]$Domain)
    return $HostsText -match "(?im)^\s*(0\.0\.0\.0|127\.0\.0\.1|::1)\s+.*\b$([regex]::Escape($Domain))\b"
}

function Resolve-PathOrExit {
    param([string]$InputPath)
    try {
        return (Resolve-Path -LiteralPath $InputPath -ErrorAction Stop).Path.TrimEnd([char[]]@('\', '/'))
    } catch {
        [Console]::Error.WriteLine("Path not found: $InputPath")
        exit 3
    }
}

function Backup-File {
    param([string]$FilePath, [string]$BackupRoot, [string]$ScanRoot)
    $relative = Get-RelativePathSafe -BasePath $ScanRoot -FullPath $FilePath
    $safeRel  = ConvertTo-SafeRelativePath -RelativePath $relative
    $backupPath = Join-Path (Join-Path $BackupRoot 'backups') $safeRel
    $backupParent = Split-Path -Parent $backupPath
    if (-not (Test-Path -LiteralPath $backupParent)) {
        [void](New-Item -ItemType Directory -Path $backupParent -Force)
    }
    Copy-Item -LiteralPath $FilePath -Destination $backupPath -Force
    return $backupPath
}

function Write-LinesUtf8NoBom {
    param([string]$FilePath, [string[]]$Lines)
    [System.IO.File]::WriteAllLines($FilePath, $Lines, $Script:Utf8NoBom)
}

function Read-TextRawSafe {
    param([string]$FilePath)
    try { return [System.IO.File]::ReadAllText($FilePath) } catch { return $null }
}

# endregion

# ============================================================================
# region Banner
# ============================================================================

function Write-Banner {
    param([string]$ActionName)
    if ($Json) { return }

    $osCaption = 'Unknown Windows'; $osVersion = ''
    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
        $osCaption = $osInfo.Caption
        $osVersion = $osInfo.Version
    } catch {
        try {
            $osInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop
            $osCaption = $osInfo.Caption
            $osVersion = $osInfo.Version
        } catch { }
    }

    Write-Host ''
    Write-Host '================================================'
    Write-Host '  BLUM PANEL WINDOWS TOOLING v1'
    Write-Host '================================================'
    Write-Host "  Action:     $ActionName"
    Write-Host "  Mode:       $Script:Mode"
    Write-Host "  OS:         $osCaption $osVersion"
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
    if ($Action -in @('Scan', 'Audit', 'Remediate', 'Forensics', 'All')) {
        Write-Host "  Path:       $Path"
    }
    if ($OutputDir) { Write-Host "  OutputDir:  $OutputDir" }
}

# endregion

# ============================================================================
# region Action: Scan
# ============================================================================

function Invoke-BlumScan {
    param([string]$ScanRoot)

    $maxBytes = [int64]$MaxFileMB * 1024 * 1024
    $kb = [int64]1024

    Write-Section '[Scan 0/12] Indexing files'
    $files = @(Get-SafeFiles -RootPath $ScanRoot -MaxBytes $maxBytes)
    Write-OK "Indexed $($files.Count) text-like files"

    $jsFiles  = @($files | Where-Object { $_.Extension -ieq '.js' })
    $luaFiles = @($files | Where-Object { $_.Extension -ieq '.lua' })
    $cfgFiles = @($files | Where-Object { $_.Extension -ieq '.cfg' -or $_.Name -ieq 'server.cfg' })
    $jsLuaCfg = @($files | Where-Object { $_.Extension -in @('.js', '.lua', '.cfg') -or $_.Name -ieq 'server.cfg' })

    Write-Section '[Scan 1/12] XOR dropper byte-pattern'
    Search-FilesForPattern -Check 'XOR dropper pattern' `
        -Pattern $Script:XorPatternRegex `
        -Severity 'High' `
        -Files $jsFiles `
        -Advice 'Active or staged JavaScript loader code. Quarantine and restore the resource from a clean source.'

    Write-Section '[Scan 2/12] Attacker identifiers'
    Search-FilesForPattern -Check 'Attacker identifier' `
        -Pattern $Script:AttackerIdRegex `
        -Severity 'High' `
        -Files $jsLuaCfg `
        -Advice 'Known Blum / Warden / Cipher / GFX strings present in executable server files.'

    Write-Section '[Scan 3/12] txAdmin tampering markers'
    Search-FilesForPattern -Check 'txAdmin backdoor indicator' `
        -Pattern $Script:TxAdminTamperRegex `
        -Severity 'High' `
        -Files (@($luaFiles) + @($files | Where-Object { $_.Extension -ieq '.json' })) `
        -Advice 'Reinstall txAdmin from an official release matching your installed version. Then audit admin accounts.'

    Write-Section '[Scan 4/12] txAdmin admin account "JohnsUrUncle"'
    $adminFiles = @($files | Where-Object {
        $_.Extension -ieq '.json' -and
        ($_.Name -ieq 'admins.json' -or $_.FullName -match '(?i)[\\/]txData[\\/]|[\\/]txAdmin[\\/]')
    })
    Search-FilesForPattern -Check 'Backdoor admin account JohnsUrUncle' `
        -Pattern '(?i)JohnsUrUncle' `
        -Severity 'High' `
        -Files $adminFiles `
        -Advice 'Delete this txAdmin admin account, rotate every txAdmin and RCON credential, then audit recent admin activity.'

    Write-Section '[Scan 5/12] txAdmin monitor file injection points'
    $monitorFiles = @($files | Where-Object {
        $_.Extension -ieq '.lua' -and $_.FullName -match '(?i)[\\/]monitor[\\/]' -and
        $_.Name -in @('cl_playerlist.lua', 'sv_main.lua', 'sv_resources.lua')
    })
    $monitorHitCount = 0
    foreach ($mf in $monitorFiles) {
        $pattern = ''
        $label   = ''
        if ($mf.Name -ieq 'cl_playerlist.lua') { $pattern = 'helpEmptyCode';                  $label = 'txAdmin cl_playerlist.lua client RCE' }
        elseif ($mf.Name -ieq 'sv_main.lua')   { $pattern = 'RESOURCE_EXCLUDE|isExcludedResource'; $label = 'txAdmin sv_main.lua resource cloaking' }
        else                                   { $pattern = 'onServerResourceFail';            $label = 'txAdmin sv_resources.lua server RCE' }

        $hits = Select-String -LiteralPath $mf.FullName -Pattern $pattern -ErrorAction SilentlyContinue
        foreach ($h in $hits) {
            Add-Finding -Severity 'High' -Check $label -File $h.Path -Line $h.LineNumber -Evidence $h.Line `
                -Advice 'Reinstall txAdmin from an official release matching your installed version. Do NOT auto-restore from master.'
            $monitorHitCount++
        }
    }
    if ($monitorFiles.Count -eq 0) {
        Write-WarnLine 'No txAdmin monitor files found under scan path (advisory only).'
    } elseif ($monitorHitCount -eq 0) {
        Write-OK 'Known txAdmin monitor backdoors not present'
    }

    Write-Section '[Scan 6/12] Suspicious dropper filenames in suspicious paths'
    $dropperHits = @($files | Where-Object {
        ($Script:DropperNames -contains $_.Name.ToLowerInvariant()) -and
        ($_.FullName -match $Script:SuspiciousResourcePathRegex)
    })
    foreach ($file in $dropperHits) {
        $contentHit = Select-String -LiteralPath $file.FullName -Pattern 'fromCharCode|eval\s*\(' -List -ErrorAction SilentlyContinue
        if ($contentHit) {
            Add-Finding -Severity 'High' -Check 'Known dropper filename with executable loader markers' `
                -File $file.FullName -Line $contentHit.LineNumber -Evidence $contentHit.Line `
                -Advice 'Inspect this resource and restore from a clean copy.'
        } else {
            Add-Finding -Severity 'Medium' -Check 'Known dropper filename in suspicious path' `
                -File $file.FullName -Evidence $file.Name `
                -Advice 'Filename matches known Blum placement names. Review manually.'
        }
    }
    if ($dropperHits.Count -eq 0) { Write-OK 'No suspicious known dropper filenames found' }

    Write-Section '[Scan 7/12] C2 domains in code'
    $domainPattern = '(?i)(' + (($Script:C2Domains | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
    Search-FilesForPattern -Check 'C2 domain reference' `
        -Pattern $domainPattern `
        -Severity 'High' `
        -Files $jsLuaCfg `
        -Advice 'Block egress to the domain and inspect the containing resource.'

    Write-Section '[Scan 8/12] Obfuscation, Luraph, and JJ-suffix loader markers'
    Search-FilesForPattern -Check 'Obfuscation or loader marker' `
        -Pattern $Script:ObfuscationRegex `
        -Severity 'Medium' `
        -Files (@($jsFiles) + @($luaFiles)) `
        -Advice 'Likely obfuscated Lua/JS loader code. Review in context.'

    Write-Section '[Scan 9/12] fxmanifest.lua suspicious entries'
    $manifests = @($files | Where-Object { $_.Name -ieq 'fxmanifest.lua' -or $_.Name -ieq '__resource.lua' })
    Search-FilesForPattern -Check 'Suspicious manifest entry' `
        -Pattern $Script:ManifestSuspiciousRegex `
        -Severity 'Medium' `
        -Files $manifests `
        -Advice 'Blum payloads commonly add hidden JS paths to resource manifests.'

    Write-Section '[Scan 10/12] Discord webhook IOC'
    Search-FilesForPattern -Check 'Blum Discord webhook IOC' `
        -Pattern $Script:DiscordWebhookRegex `
        -Severity 'High' `
        -Files (@($jsFiles) + @($luaFiles)) `
        -Advice 'Webhook phone-home indicator found. Treat the resource as compromised.'

    Write-Section '[Scan 11/12] Known payload size ranges'
    $sizeCandidates = @(Get-ChildItem -LiteralPath $ScanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            -not ($Script:SelfNames -contains $_.Name.ToLowerInvariant()) -and
            $_.Extension.ToLowerInvariant() -in @('.js', '.lua', '.bin', '.txt')
        })
    $sizeHitCount = 0
    foreach ($file in $sizeCandidates) {
        $size = [int64]$file.Length
        $reason = $null
        if ($size -ge (420 * $kb) -and $size -le (470 * $kb) -and $file.Extension -ieq '.js') {
            $reason = 'size resembles JScrambler dropper payload'
        } elseif ($size -ge (1600 * $kb) -and $size -le (1650 * $kb) -and $file.Extension -ieq '.js') {
            $reason = 'size resembles live C2 replicator payload'
        } elseif ($size -ge (40 * $kb) -and $size -le (46 * $kb) -and $file.Extension -ieq '.js') {
            $reason = 'size resembles XOR yarn/webpack dropper variant'
        } elseif ($size -ge (60 * $kb) -and $size -le (67 * $kb) -and $file.Extension -ieq '.lua') {
            $reason = 'size resembles Luraph Lua payload'
        }
        if ($reason) {
            Add-Finding -Severity 'Low' -Check 'Known payload size range' `
                -File $file.FullName -Evidence "$size bytes; $reason" `
                -Advice 'Size alone is not proof. Search this file for the high-severity strings above.'
            $sizeHitCount++
        }
    }
    if ($sizeHitCount -eq 0) { Write-OK 'No files matched known payload size ranges' }

    Write-Section '[Scan 12/12] Hosts blocking and active C2 connections'
    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    if (Test-Path -LiteralPath $hostsPath) {
        $hostsText = Get-Content -LiteralPath $hostsPath -Raw -ErrorAction SilentlyContinue
        foreach ($d in @('9ns1.com', 'fivems.lt', 'blum-panel.me', 'warden-panel.me', 'gfxpanel.org')) {
            if (Test-IsHostsBlockedDomain -HostsText $hostsText -Domain $d) {
                Write-OK "hosts blocks $d"
            } else {
                Write-WarnLine "hosts does not block $d (advisory only, not an infection indicator)"
            }
        }
    } else {
        Write-WarnLine "Windows hosts file not found at $hostsPath (advisory only)"
    }

    if (-not $NoNetwork) {
        $connectionHits = @()
        try {
            $connections = Get-NetTCPConnection -ErrorAction Stop
            foreach ($c in $connections) {
                if ($Script:DirectIps -contains $c.RemoteAddress) {
                    $connectionHits += [pscustomobject]@{
                        RemoteAddress = $c.RemoteAddress
                        RemotePort    = $c.RemotePort
                        State         = $c.State
                        OwningProcess = $c.OwningProcess
                    }
                }
            }
        } catch {
            $netstat = & netstat.exe -ano 2>$null
            foreach ($line in $netstat) {
                foreach ($ip in $Script:DirectIps) {
                    if ($line -match ([regex]::Escape($ip))) {
                        $connectionHits += [pscustomobject]@{
                            RemoteAddress = $ip
                            RemotePort    = ''
                            State         = 'netstat'
                            OwningProcess = ($line -replace '\s+', ' ').Trim()
                        }
                    }
                }
            }
        }

        foreach ($h in $connectionHits) {
            $procLabel = "PID=$($h.OwningProcess)"
            if ($h.OwningProcess -match '^\d+$') {
                $proc = Get-Process -Id ([int]$h.OwningProcess) -ErrorAction SilentlyContinue
                if ($proc) { $procLabel = "$($proc.ProcessName) PID=$($h.OwningProcess)" }
            }
            Add-Finding -Severity 'High' -Check 'Active connection to known direct C2/file server IP' `
                -Evidence "$($h.RemoteAddress):$($h.RemotePort) $($h.State) $procLabel" `
                -Advice 'Identify the process and isolate the server before cleanup.'
        }
        if ($connectionHits.Count -eq 0) { Write-OK 'No active TCP connections to known direct C2 IPs' }
    }
}

# endregion

# ============================================================================
# region Action: Audit
# ============================================================================

function Invoke-BlumAudit {
    param([string]$ScanRoot)

    Write-Section '[Audit 1/8] txAdmin admin accounts'
    $adminFiles = @(Get-ChildItem -LiteralPath $ScanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            $_.Extension -ieq '.json' -and
            ($_.Name -ieq 'admins.json' -or $_.FullName -match '(?i)[\\/]txData[\\/]|[\\/]txAdmin[\\/]')
        })

    if ($adminFiles.Count -eq 0) {
        Write-WarnLine 'No txAdmin admins.json file found under scan path.'
    } else {
        foreach ($af in $adminFiles) {
            try {
                $raw = Get-Content -LiteralPath $af.FullName -Raw -ErrorAction Stop
                $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
                $names = @()
                if ($parsed -is [array]) {
                    foreach ($adm in $parsed) {
                        if ($adm.PSObject.Properties.Name -contains 'name') {
                            $names += $adm.name
                        } elseif ($adm.PSObject.Properties.Name -contains 'username') {
                            $names += $adm.username
                        }
                    }
                }
                Write-InfoLine "$($af.FullName) admin count: $($names.Count)"
                foreach ($n in $names) {
                    if ($n -imatch 'JohnsUrUncle') {
                        Add-Finding -Severity 'High' -Check 'Backdoor admin account JohnsUrUncle' -File $af.FullName -Evidence "name=$n" `
                            -Advice 'Delete this account and rotate txAdmin / RCON / database credentials.'
                    } else {
                        Write-InfoLine "  admin: $n"
                    }
                }
            } catch {
                Write-WarnLine "Could not parse $($af.FullName) as JSON; falling back to string match."
                $hit = Select-String -LiteralPath $af.FullName -Pattern '(?i)JohnsUrUncle' -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($hit) {
                    Add-Finding -Severity 'High' -Check 'Backdoor admin account JohnsUrUncle' -File $af.FullName -Line $hit.LineNumber -Evidence $hit.Line `
                        -Advice 'Delete this account and rotate txAdmin / RCON / database credentials.'
                }
            }
        }
    }

    Write-Section '[Audit 2/8] Scheduled tasks'
    try {
        $tasks = Get-ScheduledTask -ErrorAction Stop
        $suspectTaskCount = 0
        foreach ($t in $tasks) {
            $actions = @($t.Actions)
            foreach ($a in $actions) {
                $exec = ''
                if ($a.PSObject.Properties.Name -contains 'Execute') { $exec = "$($a.Execute) $($a.Arguments)" }
                elseif ($a.PSObject.Properties.Name -contains 'Path') { $exec = $a.Path }
                if (-not $exec) { continue }

                $isFXFlavoured = $exec -imatch '(FXServer|server-data|txAdmin|fivem)'
                $isScripty     = $exec -imatch '\.(ps1|js|bat|vbs|cmd)\b' -or $exec -imatch '\bpowershell\b|\bcmd\b|\bwscript\b|\bcscript\b|\brundll32\b|\bmshta\b'
                $isWebish      = $exec -imatch 'http[s]?://|Invoke-WebRequest|Invoke-Expression|\biwr\b|\biex\b|DownloadString|FromBase64String'
                $touchesC2     = $false
                foreach ($d in $Script:C2Domains) {
                    if ($exec -imatch [regex]::Escape($d)) { $touchesC2 = $true; break }
                }

                if ($touchesC2) {
                    Add-Finding -Severity 'High' -Check 'Scheduled task references known C2 domain' `
                        -File "Task=$($t.TaskPath)$($t.TaskName)" -Evidence $exec `
                        -Advice 'Disable and delete the task, then identify what created it.'
                    $suspectTaskCount++
                } elseif ($isFXFlavoured -and ($isScripty -or $isWebish)) {
                    Add-Finding -Severity 'Medium' -Check 'Scheduled task touches FXServer with scripting/web behaviour' `
                        -File "Task=$($t.TaskPath)$($t.TaskName)" -Evidence $exec `
                        -Advice 'Confirm the task was created intentionally; attackers commonly add a scheduled re-installer.'
                    $suspectTaskCount++
                } elseif ($isWebish -and $isScripty) {
                    Add-Finding -Severity 'Low' -Check 'Scheduled task with powershell/cmd download-and-execute pattern' `
                        -File "Task=$($t.TaskPath)$($t.TaskName)" -Evidence $exec `
                        -Advice 'Review the task even if it is not Blum-specific.'
                }
            }
        }
        if ($suspectTaskCount -eq 0) { Write-OK 'No suspicious scheduled tasks found' }
    } catch {
        Write-WarnLine "Could not enumerate scheduled tasks: $($_.Exception.Message)"
    }

    Write-Section '[Audit 3/8] Registry Run keys'
    $runKeys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    )
    $runHitCount = 0
    foreach ($key in $runKeys) {
        if (-not (Test-Path -LiteralPath $key)) { continue }
        try {
            $props = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            $names = @($props.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' -and $_.Name -notlike 'PS*' })
            foreach ($p in $names) {
                $val = [string]$p.Value
                if (-not $val) { continue }
                $hitC2 = $false
                foreach ($d in $Script:C2Domains) { if ($val -imatch [regex]::Escape($d)) { $hitC2 = $true; break } }
                $hitFx = $val -imatch '(FXServer|server-data|txAdmin)'
                $hitDl = $val -imatch 'Invoke-WebRequest|Invoke-Expression|DownloadString|FromBase64String|http[s]?://'

                if ($hitC2) {
                    Add-Finding -Severity 'High' -Check 'Registry Run key references known C2 domain' `
                        -File "$key!$($p.Name)" -Evidence $val `
                        -Advice 'Delete the value and identify what added it.'
                    $runHitCount++
                } elseif ($hitFx -and $hitDl) {
                    Add-Finding -Severity 'Medium' -Check 'Registry Run key downloads-and-executes near FXServer' `
                        -File "$key!$($p.Name)" -Evidence $val `
                        -Advice 'Confirm the value was added intentionally.'
                    $runHitCount++
                } elseif ($hitDl) {
                    Add-Finding -Severity 'Low' -Check 'Registry Run key with download-and-execute pattern' `
                        -File "$key!$($p.Name)" -Evidence $val `
                        -Advice 'Review even if it is not Blum-specific.'
                    $runHitCount++
                }
            }
        } catch {
            Write-WarnLine "Could not read $key`: $($_.Exception.Message)"
        }
    }
    if ($runHitCount -eq 0) { Write-OK 'No suspicious Run-key entries found' }

    Write-Section '[Audit 4/8] Windows services'
    try {
        $services = Get-CimInstance -ClassName Win32_Service -ErrorAction Stop
        $svcHitCount = 0
        foreach ($svc in $services) {
            $exec = $svc.PathName
            if (-not $exec) { continue }
            $hitC2 = $false
            foreach ($d in $Script:C2Domains) { if ($exec -imatch [regex]::Escape($d)) { $hitC2 = $true; break } }
            $hitFx = $exec -imatch '(server-data|txAdmin)'
            $isPs  = $exec -imatch '\bpowershell\b' -and $exec -imatch '(-Enc|-EncodedCommand|FromBase64String|DownloadString|Invoke-Expression|\biex\b)'

            if ($hitC2) {
                Add-Finding -Severity 'High' -Check 'Service references known C2 domain' `
                    -File "Service=$($svc.Name)" -Evidence $exec `
                    -Advice 'Stop and remove the service, then identify what created it.'
                $svcHitCount++
            } elseif ($isPs) {
                Add-Finding -Severity 'Medium' -Check 'Service uses encoded/downloading PowerShell' `
                    -File "Service=$($svc.Name)" -Evidence $exec `
                    -Advice 'Confirm the service was added intentionally.'
                $svcHitCount++
            } elseif ($hitFx -and $exec -imatch '\.(ps1|bat|vbs|cmd|js)\b') {
                Add-Finding -Severity 'Low' -Check 'Service points at scripted launcher inside FXServer tree' `
                    -File "Service=$($svc.Name)" -Evidence $exec `
                    -Advice 'Review.'
                $svcHitCount++
            }
        }
        if ($svcHitCount -eq 0) { Write-OK 'No suspicious services found' }
    } catch {
        Write-WarnLine "Could not enumerate services: $($_.Exception.Message)"
    }

    Write-Section '[Audit 5/8] WMI permanent event subscriptions'
    try {
        $consumers = Get-CimInstance -Namespace 'root\subscription' -ClassName '__EventConsumer' -ErrorAction Stop
        if (-not $consumers -or $consumers.Count -eq 0) {
            Write-OK 'No WMI permanent event consumers (clean)'
        } else {
            foreach ($c in $consumers) {
                $cmd = ''
                if ($c.PSObject.Properties.Name -contains 'CommandLineTemplate') { $cmd = $c.CommandLineTemplate }
                Add-Finding -Severity 'Medium' -Check 'WMI permanent event consumer present' `
                    -File "$($c.__CLASS):$($c.Name)" -Evidence $cmd `
                    -Advice 'Permanent WMI subscriptions are a known persistence vector. Confirm legitimate origin.'
            }
        }
    } catch {
        Write-WarnLine "Could not enumerate WMI subscriptions: $($_.Exception.Message)"
    }

    Write-Section '[Audit 6/8] Defender exclusion paths'
    try {
        $pref = Get-MpPreference -ErrorAction Stop
        $excluded = @()
        if ($pref.ExclusionPath) { $excluded = @($pref.ExclusionPath) }
        if ($excluded.Count -eq 0) {
            Write-OK 'No Defender path exclusions set'
        } else {
            foreach ($e in $excluded) {
                if ($e -imatch '(server-data|txAdmin|FXServer|fivem)') {
                    Add-Finding -Severity 'Medium' -Check 'Defender exclusion covers FiveM/txAdmin paths' `
                        -File 'Defender' -Evidence $e `
                        -Advice 'Attackers commonly add exclusions to silence Defender. Confirm this exclusion was added by you.'
                } else {
                    Write-InfoLine "exclusion: $e"
                }
            }
        }
    } catch {
        Write-WarnLine "Could not query Defender exclusions: $($_.Exception.Message)"
    }

    Write-Section '[Audit 7/8] DNS client cache for known C2'
    try {
        $cache = Get-DnsClientCache -ErrorAction Stop
        $cacheHits = @()
        foreach ($entry in $cache) {
            foreach ($d in $Script:C2Domains) {
                if ($entry.Entry -ieq $d -or $entry.Name -ieq $d -or $entry.Entry -imatch ('\b' + [regex]::Escape($d) + '$')) {
                    $cacheHits += $entry
                    break
                }
            }
        }
        if ($cacheHits.Count -eq 0) {
            Write-OK 'DNS client cache contains no known C2 entries'
        } else {
            foreach ($h in $cacheHits) {
                Add-Finding -Severity 'High' -Check 'DNS client cache holds resolution for known C2 domain' `
                    -File 'DnsClientCache' -Evidence "$($h.Entry) -> $($h.Data)" `
                    -Advice 'Recent C2 lookup. Identify the process that resolved it; flush DNS cache after triage.'
            }
        }
    } catch {
        Write-WarnLine "Could not read DNS client cache: $($_.Exception.Message)"
    }

    Write-Section '[Audit 8/8] Recently-modified scripts in resources (30d)'
    $cutoff = (Get-Date).AddDays(-30)
    $recent = @(Get-ChildItem -LiteralPath $ScanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            -not ($Script:SelfNames -contains $_.Name.ToLowerInvariant()) -and
            $_.Extension.ToLowerInvariant() -in @('.js', '.lua') -and
            $_.LastWriteTime -ge $cutoff
        } |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 50)
    if ($recent.Count -eq 0) {
        Write-OK 'No .js/.lua under scan path modified in last 30 days'
    } else {
        Write-InfoLine "Top $($recent.Count) recently-modified scripts (review for unexpected changes):"
        foreach ($r in $recent) {
            Write-InfoLine "$($r.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))  $($r.FullName)"
        }
    }
}

# endregion

# ============================================================================
# region Action: Forensics
# ============================================================================

function Invoke-BlumForensics {
    param([string]$ScanRoot, [string]$EvidenceDir)

    if (-not $EvidenceDir) {
        $EvidenceDir = Join-Path (Get-Location).Path "blum-evidence-$Script:TimeStamp"
    }
    if (-not (Test-Path -LiteralPath $EvidenceDir)) {
        [void](New-Item -ItemType Directory -Path $EvidenceDir -Force)
    }
    Write-InfoLine "Evidence dir: $EvidenceDir" 'Cyan'

    Write-Section '[Forensics 1/7] Process snapshot'
    try {
        $procs = Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
            Select-Object ProcessId, ParentProcessId, Name, CommandLine, ExecutablePath, CreationDate
        $procs | Export-Csv -LiteralPath (Join-Path $EvidenceDir 'processes.csv') -NoTypeInformation -Encoding UTF8
        Write-OK "$($procs.Count) processes saved to processes.csv"

        # Highlight FXServer, node, and powershell processes inline for quick review
        $hl = @($procs | Where-Object { $_.Name -imatch 'FXServer|node\.exe|powershell|cmd\.exe|wscript|cscript|mshta|rundll32' })
        foreach ($p in $hl) {
            Write-InfoLine "PID=$($p.ProcessId) PPID=$($p.ParentProcessId) $($p.Name)  $(ConvertTo-ShortString $p.CommandLine 180)"
        }
    } catch {
        Add-WarningLine "Could not snapshot processes: $($_.Exception.Message)"
    }

    Write-Section '[Forensics 2/7] TCP connection snapshot'
    try {
        $conns = Get-NetTCPConnection -ErrorAction Stop
        $rows = @()
        foreach ($c in $conns) {
            $procName = ''
            if ($c.OwningProcess -gt 0) {
                $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
                if ($proc) { $procName = $proc.ProcessName }
            }
            $rows += [pscustomobject]@{
                LocalAddress  = $c.LocalAddress
                LocalPort     = $c.LocalPort
                RemoteAddress = $c.RemoteAddress
                RemotePort    = $c.RemotePort
                State         = $c.State
                ProcessId     = $c.OwningProcess
                ProcessName   = $procName
            }
        }
        $rows | Export-Csv -LiteralPath (Join-Path $EvidenceDir 'tcp_connections.csv') -NoTypeInformation -Encoding UTF8
        Write-OK "$($rows.Count) connections saved to tcp_connections.csv"
    } catch {
        Add-WarningLine "Could not snapshot TCP connections: $($_.Exception.Message)"
    }

    Write-Section '[Forensics 3/7] Hosts file copy'
    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
    if (Test-Path -LiteralPath $hostsPath) {
        Copy-Item -LiteralPath $hostsPath -Destination (Join-Path $EvidenceDir 'hosts') -Force
        Write-OK 'hosts copied'
    } else {
        Add-WarningLine "hosts file not found at $hostsPath"
    }

    Write-Section '[Forensics 4/7] Windows event log windows (last 24h)'
    $eventOutDir = Join-Path $EvidenceDir 'eventlogs'
    [void](New-Item -ItemType Directory -Path $eventOutDir -Force)
    $since = (Get-Date).AddHours(-24)
    $logs = @(
        @{ Name = 'Security';                      Ids = @(4624, 4625, 4688, 4720, 4732) },
        @{ Name = 'System';                        Ids = @(7045) },
        @{ Name = 'Microsoft-Windows-PowerShell/Operational'; Ids = @(4103, 4104) },
        @{ Name = 'Application';                   Ids = @() }
    )
    foreach ($log in $logs) {
        try {
            $filter = @{ LogName = $log.Name; StartTime = $since }
            if ($log.Ids.Count -gt 0) { $filter['Id'] = $log.Ids }
            $events = Get-WinEvent -FilterHashtable $filter -MaxEvents 500 -ErrorAction Stop
            $safeName = ($log.Name -replace '[\\/]', '-')
            $events | Select-Object TimeCreated, Id, ProviderName, Message |
                Export-Csv -LiteralPath (Join-Path $eventOutDir "$safeName.csv") -NoTypeInformation -Encoding UTF8
            Write-OK "$safeName : $($events.Count) events"
        } catch {
            Write-WarnLine "Could not read event log $($log.Name): $($_.Exception.Message)"
        }
    }

    Write-Section '[Forensics 5/7] txAdmin config copy'
    $txTargets = @(Get-ChildItem -LiteralPath $ScanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            ($_.Name -ieq 'admins.json' -or $_.Name -ieq 'config.json') -and
            ($_.FullName -match '(?i)[\\/]txData[\\/]|[\\/]txAdmin[\\/]')
        })
    if ($txTargets.Count -eq 0) {
        Write-WarnLine 'No txAdmin admins.json or config.json found under scan path.'
    } else {
        $txDir = Join-Path $EvidenceDir 'txAdmin'
        [void](New-Item -ItemType Directory -Path $txDir -Force)
        foreach ($t in $txTargets) {
            $rel = Get-RelativePathSafe -BasePath $ScanRoot -FullPath $t.FullName
            $dst = Join-Path $txDir (ConvertTo-SafeRelativePath -RelativePath $rel)
            $dstParent = Split-Path -Parent $dst
            if (-not (Test-Path -LiteralPath $dstParent)) {
                [void](New-Item -ItemType Directory -Path $dstParent -Force)
            }
            Copy-Item -LiteralPath $t.FullName -Destination $dst -Force
            Write-OK "copied $rel"
        }
    }

    Write-Section '[Forensics 6/7] SHA256 hashes'
    if (-not $IncludeHashes) {
        Write-InfoLine 'Skipped (pass -IncludeHashes to compute hashes for every .js/.lua under the scan path).'
    } else {
        $maxBytes = [int64]$MaxFileMB * 1024 * 1024
        $hashTargets = @(Get-ChildItem -LiteralPath $ScanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                -not ($Script:SelfNames -contains $_.Name.ToLowerInvariant()) -and
                $_.Extension.ToLowerInvariant() -in @('.js', '.lua') -and
                $_.Length -le $maxBytes
            })
        $hashRows = @()
        foreach ($f in $hashTargets) {
            try {
                $h = Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop
                $hashRows += [pscustomobject]@{
                    Path   = $f.FullName
                    Size   = $f.Length
                    SHA256 = $h.Hash
                }
            } catch {
                # skip unreadable
            }
        }
        $hashRows | Export-Csv -LiteralPath (Join-Path $EvidenceDir 'sha256.csv') -NoTypeInformation -Encoding UTF8
        Write-OK "Hashed $($hashRows.Count) files into sha256.csv"
    }

    Write-Section '[Forensics 7/7] Optional zip'
    if ($IncludeForensicsZip) {
        $zipPath = "$EvidenceDir.zip"
        try {
            if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
            Compress-Archive -Path (Join-Path $EvidenceDir '*') -DestinationPath $zipPath -CompressionLevel Optimal
            Write-OK "Evidence zip: $zipPath"
        } catch {
            Add-WarningLine "Could not create zip: $($_.Exception.Message)"
        }
    } else {
        Write-InfoLine 'Skipped (pass -IncludeForensicsZip to bundle the evidence directory).'
    }

    return $EvidenceDir
}

# endregion

# ============================================================================
# region Action: Block
# ============================================================================

function Invoke-BlumBlock {
    $ruleGroup = 'Blum Panel C2 Block'
    $hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'

    if ($Apply -or $Undo) {
        if (-not (Test-IsAdmin)) {
            [Console]::Error.WriteLine('Block with -Apply or -Undo requires Administrator. Reopen PowerShell elevated.')
            exit 3
        }
    } elseif (-not $Apply -and -not $Undo) {
        Write-WarnLine 'Dry-run only. Re-run with -Apply to write hosts and firewall rules.'
    }

    if ($Undo) {
        Write-Section '[Block undo] Removing firewall rules created by this script'
        try {
            $rules = Get-NetFirewallRule -Group $ruleGroup -ErrorAction Stop
        } catch { $rules = @() }
        if ($rules) {
            $rules | Remove-NetFirewallRule -ErrorAction SilentlyContinue
            Write-InfoLine "Removed firewall rules in group: $ruleGroup" 'Green'
            Add-Action -Type 'BlockUndo' -Target $ruleGroup -Reason 'Removed firewall rules' -Result 'Done'
        } else {
            Write-WarnLine "No firewall rules found in group: $ruleGroup"
        }
        Write-WarnLine 'Hosts entries are not removed automatically. Restore from a hosts backup file if required.'
        return
    }

    Write-Section '[Block 1/2] Hosts file domain blocking'
    if (-not (Test-Path -LiteralPath $hostsPath)) {
        Add-WarningLine "Hosts file not found: $hostsPath"
    } else {
        $hostsText = Get-Content -LiteralPath $hostsPath -Raw -ErrorAction SilentlyContinue
        $missing = @()
        foreach ($d in $Script:C2Domains) {
            if (-not (Test-IsHostsBlockedDomain -HostsText $hostsText -Domain $d)) { $missing += $d }
        }

        if ($missing.Count -eq 0) {
            Write-OK 'All listed C2 domains already appear blocked in hosts'
        } else {
            Write-InfoLine "Domains to add: $($missing.Count)" 'Yellow'
            foreach ($d in $missing) {
                Write-InfoLine "  0.0.0.0 $d"
                Write-InfoLine "  0.0.0.0 www.$d"
            }
            if ($Apply) {
                $backupPath = "$hostsPath.blum-backup-$Script:TimeStamp"
                try {
                    Copy-Item -LiteralPath $hostsPath -Destination $backupPath -Force
                    $lines = New-Object System.Collections.Generic.List[string]
                    [void]$lines.Add('')
                    [void]$lines.Add("# Blum Panel C2 block entries added $(Get-Date -Format s)")
                    foreach ($d in $missing) {
                        [void]$lines.Add("0.0.0.0 $d")
                        [void]$lines.Add("0.0.0.0 www.$d")
                    }
                    Add-Content -LiteralPath $hostsPath -Value $lines
                    Write-InfoLine "Updated hosts. Backup: $backupPath" 'Green'
                    Add-Action -Type 'HostsBlock' -Target $hostsPath -Reason "Added $($missing.Count) domains" -Result 'Done'
                } catch {
                    Add-WarningLine "Failed to update hosts: $($_.Exception.Message)"
                }
            }
        }
    }

    Write-Section '[Block 2/2] Windows Defender Firewall outbound rules'
    foreach ($ip in $Script:DirectIps) {
        $ruleName = "Blum Panel C2 Block $ip"
        $existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-OK "exists: $ruleName"
            continue
        }
        if ($Apply) {
            try {
                [void](New-NetFirewallRule `
                    -DisplayName $ruleName `
                    -Group $ruleGroup `
                    -Direction Outbound `
                    -Action Block `
                    -RemoteAddress $ip `
                    -Profile Any `
                    -Enabled True)
                Write-InfoLine "added: $ruleName" 'Green'
                Add-Action -Type 'FirewallRule' -Target $ip -Reason 'Outbound block' -Result 'Done'
            } catch {
                Add-WarningLine "Failed to add ${ruleName}: $($_.Exception.Message)"
            }
        } else {
            Write-InfoLine "would add outbound block rule for $ip"
            Add-Action -Type 'FirewallRule' -Target $ip -Reason 'Outbound block (planned)'
        }
    }

    if ($Apply) {
        Write-InfoLine 'Flush DNS cache: ipconfig /flushdns' 'Cyan'
    }
}

# endregion

# ============================================================================
# region Action: Remediate
# ============================================================================

function Invoke-BlumRemediate {
    param([string]$ScanRoot)

    $maxBytes = [int64]$MaxFileMB * 1024 * 1024
    $quarantineDir = Join-Path $ScanRoot "_blum_quarantine_$Script:TimeStamp"

    if ($Apply) {
        Write-WarnLine 'Apply mode. Files will be MOVED to a quarantine directory; manifests will be edited; backups are kept.'
    } else {
        Write-WarnLine 'Dry-run only. Re-run with -Apply to act.'
    }

    Write-Section '[Remediate 1/4] Identifying high- and medium-confidence files'
    $files = @(Get-SafeFiles -RootPath $ScanRoot -MaxBytes $maxBytes -ExcludeUnder $quarantineDir)
    foreach ($f in $files) {
        $text = Read-TextRawSafe -FilePath $f.FullName
        if ($null -eq $text) { continue }
        $name = $f.Name.ToLowerInvariant()
        $ext  = $f.Extension.ToLowerInvariant()
        $suspectPath = $f.FullName -match $Script:SuspiciousResourcePathRegex

        $reason = $null; $sev = $null
        if ($ext -eq '.js' -and $text -match $Script:XorPatternRegex -and $text -match 'eval\s*\(') {
            $reason = 'XOR JavaScript dropper with eval'; $sev = 'High'
        } elseif (($ext -eq '.js' -or $ext -eq '.lua') -and ($text -match (
                '(?i)(' + (($Script:C2Domains | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
            )) -and $text -match $Script:LoaderBehaviourRegex) {
            $reason = 'Known C2 reference combined with loader behaviour'; $sev = 'High'
        } elseif (($Script:DropperNames -contains $name) -and $suspectPath -and $text -match '(?i)(fromCharCode|eval\s*\(|https\.get|PerformHttpRequest)') {
            $reason = 'Known dropper filename in suspicious path with loader markers'; $sev = 'High'
        } elseif (($Script:DropperNames -contains $name) -and $suspectPath) {
            $reason = 'Known dropper filename in suspicious path'; $sev = 'Medium'
        } elseif (($ext -eq '.js' -or $ext -eq '.lua') -and $text -match $Script:ObfuscationRegex) {
            $reason = 'Obfuscation or loader marker matched'; $sev = 'Medium'
        }

        if ($reason) {
            $relative = Get-RelativePathSafe -BasePath $ScanRoot -FullPath $f.FullName
            [void]$Script:Quarantine.Add([pscustomobject]@{
                path     = $f.FullName
                relative = $relative
                severity = $sev
                reason   = $reason
                size     = [int64]$f.Length
            })
        }
    }

    if ($Script:Quarantine.Count -eq 0) {
        Write-OK 'No high or medium confidence files selected.'
    } else {
        foreach ($q in $Script:Quarantine) {
            Write-InfoLine "[$($q.severity)] $($q.relative) - $($q.reason)" 'Yellow'
            Add-Action -Type 'Quarantine' -Target $q.path -Reason "[$($q.severity)] $($q.reason)"
        }
    }

    Write-Section '[Remediate 2/4] Quarantine'
    if ($Apply -and $Script:Quarantine.Count -gt 0) {
        if (-not (Test-Path -LiteralPath $quarantineDir)) {
            [void](New-Item -ItemType Directory -Path $quarantineDir -Force)
        }
    }
    foreach ($q in $Script:Quarantine) {
        $safeRel = ConvertTo-SafeRelativePath -RelativePath $q.relative
        $dest = Join-Path (Join-Path $quarantineDir 'files') $safeRel
        if ($Apply) {
            try {
                $destParent = Split-Path -Parent $dest
                if (-not (Test-Path -LiteralPath $destParent)) {
                    [void](New-Item -ItemType Directory -Path $destParent -Force)
                }
                Move-Item -LiteralPath $q.path -Destination $dest -Force
                Write-InfoLine "moved: $($q.relative)" 'Green'
            } catch {
                Add-WarningLine "Failed to quarantine $($q.path): $($_.Exception.Message)"
            }
        }
    }

    Write-Section '[Remediate 3/4] Manifest cleanup'
    if ($SkipManifestCleanup) {
        Write-InfoLine 'Skipped (-SkipManifestCleanup).'
    } else {
        $manifests = @(Get-ChildItem -LiteralPath $ScanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                -not $_.FullName.StartsWith($quarantineDir, [StringComparison]::OrdinalIgnoreCase) -and
                ($_.Name -ieq 'fxmanifest.lua' -or $_.Name -ieq '__resource.lua')
            })
        $dropperPattern = '(?i)(' + (($Script:DropperNames | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')'
        foreach ($m in $manifests) {
            $orig = @(Get-Content -LiteralPath $m.FullName -ErrorAction SilentlyContinue)
            if ($orig.Count -eq 0) { continue }

            $kept = New-Object System.Collections.Generic.List[string]
            $removed = New-Object System.Collections.Generic.List[string]
            $manifestDir = Split-Path -Parent $m.FullName

            foreach ($line in $orig) {
                $norm = $line -replace '\\', '/'
                $remove = $false
                foreach ($q in $Script:Quarantine) {
                    if (-not $q.path.StartsWith($manifestDir, [StringComparison]::OrdinalIgnoreCase)) { continue }
                    $rel = Get-RelativePathSafe -BasePath $manifestDir -FullPath $q.path
                    $relForward = $rel -replace '\\', '/'
                    if ($norm -match [regex]::Escape($relForward)) { $remove = $true; break }
                }
                if (-not $remove -and $norm -match '(?i)(node_modules/\.cache|middleware/|dist/|server/|modules/)' -and $norm -match $dropperPattern) {
                    $remove = $true
                }
                if ($remove) { [void]$removed.Add($line) } else { [void]$kept.Add($line) }
            }

            if ($removed.Count -gt 0) {
                Write-InfoLine "manifest cleanup planned: $($m.FullName) ($($removed.Count) lines)" 'Yellow'
                Add-Action -Type 'CleanManifest' -Target $m.FullName -Reason "$($removed.Count) suspicious manifest line(s)"
                if ($Apply) {
                    try {
                        [void](Backup-File -FilePath $m.FullName -BackupRoot $quarantineDir -ScanRoot $ScanRoot)
                        Write-LinesUtf8NoBom -FilePath $m.FullName -Lines $kept.ToArray()
                        Write-InfoLine "manifest cleaned: $($m.FullName)" 'Green'
                    } catch {
                        Add-WarningLine "Failed to clean manifest $($m.FullName): $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    Write-Section '[Remediate 4/4] txAdmin tampering check'
    if ($SkipTxAdminCheck) {
        Write-InfoLine 'Skipped (-SkipTxAdminCheck).'
    } else {
        $monitorFiles = @(Get-ChildItem -LiteralPath $ScanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                $_.FullName -match '(?i)[\\/]monitor[\\/]' -and
                $_.Name -in @('cl_playerlist.lua', 'sv_main.lua', 'sv_resources.lua')
            })

        $tamperedAny = $false
        foreach ($mf in $monitorFiles) {
            $text = Read-TextRawSafe -FilePath $mf.FullName
            if ($null -eq $text) { continue }
            $matched = $false
            if ($mf.Name -ieq 'cl_playerlist.lua' -and $text -match 'helpEmptyCode') { $matched = $true }
            elseif ($mf.Name -ieq 'sv_main.lua'   -and $text -match 'RESOURCE_EXCLUDE|isExcludedResource') { $matched = $true }
            elseif ($mf.Name -ieq 'sv_resources.lua' -and $text -match 'onServerResourceFail') { $matched = $true }
            if ($matched) {
                $tamperedAny = $true
                Add-WarningLine "txAdmin tampering detected in $($mf.FullName)"
                Add-Action -Type 'TxAdminManualReinstallRequired' -Target $mf.FullName -Reason 'Detected known monitor injection marker'
            }
        }

        $adminHits = @(Get-ChildItem -LiteralPath $ScanRoot -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '[\\/]\.git[\\/]' -and
                $_.Extension -ieq '.json' -and
                ($_.Name -ieq 'admins.json' -or $_.FullName -match '(?i)[\\/]txData[\\/]|[\\/]txAdmin[\\/]')
            } |
            Select-String -Pattern '(?i)JohnsUrUncle' -ErrorAction SilentlyContinue)

        foreach ($h in $adminHits) {
            $tamperedAny = $true
            Add-WarningLine "Backdoor admin string in $($h.Path):$($h.LineNumber). Remove via the txAdmin UI after backing up admins.json."
            Add-Action -Type 'ManualAdminRemovalRequired' -Target $h.Path -Reason 'JohnsUrUncle'
        }

        if ($tamperedAny) {
            Write-InfoLine '' 'Yellow'
            Write-InfoLine 'NEXT STEPS for txAdmin (manual):' 'Yellow'
            Write-InfoLine '  1. Note your installed txAdmin version (from txAdmin UI -> About).' 'Yellow'
            Write-InfoLine '  2. Stop the FiveM server.' 'Yellow'
            Write-InfoLine '  3. Reinstall txAdmin from an official release matching that version:' 'Yellow'
            Write-InfoLine '       https://github.com/tabarra/txAdmin/releases' 'Yellow'
            Write-InfoLine '  4. Do NOT replace files individually from master/main; the project has been restructured.' 'Yellow'
            Write-InfoLine '  5. Rotate txAdmin, RCON, database, FTP/SFTP, SSH/RDP, Discord bot credentials.' 'Yellow'
            Write-InfoLine '  6. Re-run this script with -Action Scan to confirm.' 'Yellow'
        } elseif ($monitorFiles.Count -eq 0) {
            Write-WarnLine 'No txAdmin monitor files found under scan path (advisory only).'
        } else {
            Write-OK 'txAdmin monitor files appear clean.'
        }
    }
}

# endregion

# ============================================================================
# region Summary
# ============================================================================

function Write-Summary {
    $high   = @($Script:Findings | Where-Object { $_.severity -eq 'High' }).Count
    $medium = @($Script:Findings | Where-Object { $_.severity -eq 'Medium' }).Count
    $low    = @($Script:Findings | Where-Object { $_.severity -eq 'Low' }).Count

    if ($Json) {
        $payload = [pscustomobject]@{
            tool          = 'blum-panel-windows-tooling'
            version       = '1'
            action        = $Action
            mode          = $Script:Mode
            generated_utc = (Get-Date).ToUniversalTime().ToString('o')
            path          = $Path
            output_dir    = $OutputDir
            summary       = [pscustomobject]@{
                high   = $high
                medium = $medium
                low    = $low
                total  = $Script:Findings.Count
                actions  = $Script:Actions.Count
                warnings = $Script:Warnings.Count
            }
            findings   = $Script:Findings
            actions    = $Script:Actions
            quarantine = $Script:Quarantine
            warnings   = $Script:Warnings
        }
        $jsonText = $payload | ConvertTo-Json -Depth 6
        if ($JsonOut) {
            # PS 5.1's Out-File -Encoding utf8 emits a BOM that breaks strict
            # JSON parsers. WriteAllText with UTF8NoBom keeps it portable.
            [System.IO.File]::WriteAllText($JsonOut, $jsonText, $Script:Utf8NoBom)
        } else {
            Write-Output $jsonText
        }
    } else {
        Write-Host ''
        Write-Host '================================================'
        Write-Host ' SUMMARY'
        Write-Host '================================================'
        Write-Host " Action:   $Action"
        Write-Host " Mode:     $Script:Mode"
        Write-Host " High:     $high"
        Write-Host " Medium:   $medium"
        Write-Host " Low:      $low"
        Write-Host " Findings: $($Script:Findings.Count)"
        Write-Host " Actions:  $($Script:Actions.Count)"
        Write-Host " Warnings: $($Script:Warnings.Count)"
        Write-Host ''
        if ($high -gt 0) {
            Write-Host 'Result: HIGH-CONFIDENCE indicators present. Treat the server as compromised until proven otherwise.' -ForegroundColor Red
            Write-Host 'Next:   Isolate, preserve evidence, run -Action Forensics, then -Action Remediate -Apply.' -ForegroundColor Red
            Write-Host ''
            Write-Host 'IMPORTANT: cleaning files is not the same as cleaning the machine.' -ForegroundColor Red
            Write-Host '  - In a Pterodactyl/Docker container on Linux, file scrub + credential rotation is usually enough.' -ForegroundColor Red
            Write-Host '  - On a Windows host running FXServer directly, the user that ran FXServer can decrypt every' -ForegroundColor Red
            Write-Host '    browser-saved password and session cookie (DPAPI). Credential rotation and force-logout-' -ForegroundColor Red
            Write-Host '    everywhere are required, and an OS reinstall is commonly required if FXServer ran as Admin.' -ForegroundColor Red
            Write-Host '  - Read docs/BLAST_RADIUS.md before assuming a scrub is enough:' -ForegroundColor Red
            Write-Host '    https://github.com/ImJer/blum-panel-fivem-backdoor-analysis/blob/main/docs/BLAST_RADIUS.md' -ForegroundColor Red
        } elseif (($medium + $low) -gt 0) {
            Write-Host 'Result: Review findings. No high-confidence indicators were found.' -ForegroundColor Yellow
        } else {
            Write-Host 'Result: No known Blum Panel indicators found.' -ForegroundColor Green
        }
        Write-Host '================================================'
    }
}

# endregion

# ============================================================================
# region Dispatch
# ============================================================================

Write-Banner -ActionName $Action

# Path is required for every action except Block.
$resolvedPath = $null
if ($Action -ne 'Block') {
    $resolvedPath = Resolve-PathOrExit -InputPath $Path
}

switch ($Action) {
    'Scan' {
        Invoke-BlumScan -ScanRoot $resolvedPath
    }
    'Audit' {
        Invoke-BlumAudit -ScanRoot $resolvedPath
    }
    'Forensics' {
        [void](Invoke-BlumForensics -ScanRoot $resolvedPath -EvidenceDir $OutputDir)
    }
    'Block' {
        Invoke-BlumBlock
    }
    'Remediate' {
        Invoke-BlumRemediate -ScanRoot $resolvedPath
    }
    'All' {
        Invoke-BlumScan -ScanRoot $resolvedPath
        Invoke-BlumAudit -ScanRoot $resolvedPath
        [void](Invoke-BlumForensics -ScanRoot $resolvedPath -EvidenceDir $OutputDir)
    }
}

Write-Summary

$highCount   = @($Script:Findings | Where-Object { $_.severity -eq 'High' }).Count
$otherCount  = @($Script:Findings | Where-Object { $_.severity -ne 'High' }).Count
if ($highCount -gt 0)  { exit 2 }
if ($otherCount -gt 0) { exit 1 }
exit 0

# endregion
