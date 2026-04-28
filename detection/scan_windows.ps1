#requires -Version 5.1
<# 
BLUM PANEL MALWARE SCANNER FOR WINDOWS v1

Read-only scanner for known Blum Panel / Warden Panel / GFX Panel FiveM
backdoor indicators. Compatible with Windows Server 2019's built-in
Windows PowerShell 5.1.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scan_windows.ps1 -Path C:\FXServer\server-data

Optional:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scan_windows.ps1 -Path C:\FXServer\server-data -Json

Notes:
  - This script does not remove files, block domains, or edit hosts.
  - Run against the FiveM server root or server-data directory, not this analysis repo.
  - Exit code 2 means high-severity indicators were found.
  - Exit code 1 means only medium/low findings were found.
  - Exit code 0 means no known indicators were found.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Path = ".",

    [int]$MaxFileMB = 30,

    [int]$MaxHitsPerCheck = 75,

    [switch]$Json,

    [switch]$NoNetstat
)

$ErrorActionPreference = "SilentlyContinue"

try {
    $Root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
} catch {
    [Console]::Error.WriteLine("Scan path not found: $Path")
    exit 3
}

$MaxBytes = [int64]$MaxFileMB * 1024 * 1024
$KB = [int64]1024
$Findings = New-Object System.Collections.Generic.List[object]

function Write-Section {
    param([string]$Message)
    if (-not $Json) {
        Write-Host ""
        Write-Host $Message -ForegroundColor Cyan
    }
}

function Write-Ok {
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

function Shorten {
    param([string]$Text, [int]$Max = 220)
    if ($null -eq $Text) { return "" }
    $Value = ($Text -replace "\s+", " ").Trim()
    if ($Value.Length -gt $Max) {
        return $Value.Substring(0, $Max) + "..."
    }
    return $Value
}

function Add-Finding {
    param(
        [ValidateSet("High", "Medium", "Low")]
        [string]$Severity,
        [string]$Check,
        [string]$File = "",
        [int]$Line = 0,
        [string]$Evidence = "",
        [string]$Advice = ""
    )

    $Finding = [pscustomobject]@{
        severity = $Severity
        check    = $Check
        file     = $File
        line     = $Line
        evidence = (Shorten $Evidence)
        advice   = $Advice
    }
    $Findings.Add($Finding) | Out-Null

    if (-not $Json) {
        $Color = "Yellow"
        if ($Severity -eq "High") { $Color = "Red" }
        elseif ($Severity -eq "Low") { $Color = "DarkYellow" }

        if ($File) {
            $LineText = ""
            if ($Line -gt 0) { $LineText = ":$Line" }
            Write-Host "  [$Severity] $Check - $File$LineText" -ForegroundColor $Color
        } else {
            Write-Host "  [$Severity] $Check" -ForegroundColor $Color
        }
        if ($Evidence) {
            Write-Host "    Evidence: $(Shorten $Evidence)" -ForegroundColor $Color
        }
        if ($Advice) {
            Write-Host "    Advice: $Advice" -ForegroundColor $Color
        }
    }
}

function Test-TextFile {
    param([System.IO.FileInfo]$File)

    $Name = $File.Name.ToLowerInvariant()
    $Ext = $File.Extension.ToLowerInvariant()

    if ($File.Length -gt $MaxBytes) { return $false }
    if ($Name -in @("fxmanifest.lua", "__resource.lua", "server.cfg", "resources.cfg")) { return $true }
    if ($Ext -in @(".js", ".lua", ".cfg", ".json", ".txt", ".html")) { return $true }
    return $false
}

function Search-Files {
    param(
        [string]$Check,
        [string]$Pattern,
        [ValidateSet("High", "Medium", "Low")]
        [string]$Severity,
        [System.IO.FileInfo[]]$Files,
        [string]$Advice = ""
    )

    $HitCount = 0
    foreach ($File in $Files) {
        if ($HitCount -ge $MaxHitsPerCheck) { break }

        $Matches = Select-String -LiteralPath $File.FullName -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue
        foreach ($Match in $Matches) {
            Add-Finding -Severity $Severity -Check $Check -File $Match.Path -Line $Match.LineNumber -Evidence $Match.Line -Advice $Advice
            $HitCount++
            if ($HitCount -ge $MaxHitsPerCheck) { break }
        }
    }

    if ($HitCount -eq 0) {
        Write-Ok "$Check clean"
    } elseif ($HitCount -ge $MaxHitsPerCheck) {
        Write-WarnLine "$Check hit limit reached ($MaxHitsPerCheck). There may be more matches."
    }
}

function Get-SafeFiles {
    param([string]$RootPath)

    Get-ChildItem -LiteralPath $RootPath -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object {
            $_.FullName -notmatch "[\\/]\.git[\\/]" -and
            (Test-TextFile $_)
        }
}

$C2Domains = @(
    "9ns1.com",
    "fivems.lt",
    "blum-panel.me",
    "blum-panel.com",
    "warden-panel.me",
    "jking.lt",
    "0xchitado.com",
    "2312321321321213.com",
    "2ns3.net",
    "5mscripts.net",
    "bhlool.com",
    "bybonvieux.com",
    "fivemgtax.com",
    "flowleakz.org",
    "giithub.net",
    "iwantaticket.org",
    "kutingplays.com",
    "l00x.org",
    "monloox.com",
    "noanimeisgay.com",
    "ryenz.net",
    "spacedev.fr",
    "trezz.org",
    "z1lly.org",
    "2nit32.com",
    "useer.it.com",
    "wsichkidolu.com",
    "cipher-panel.me",
    "ciphercheats.com",
    "keyx.club",
    "dark-utilities.xyz",
    "gfxpanel.org"
)

$DirectIps = @(
    "185.87.23.198",
    "185.80.128.35",
    "185.80.128.36",
    "185.80.130.168"
)

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
    "babel_preset.js"
)

if (-not $Json) {
    $OsCaption = "Unknown Windows"
    $OsVersion = ""
    $OsInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    if (-not $OsInfo) {
        $OsInfo = Get-WmiObject -Class Win32_OperatingSystem -ErrorAction SilentlyContinue
    }
    if ($OsInfo) {
        $OsCaption = $OsInfo.Caption
        $OsVersion = $OsInfo.Version
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host "  BLUM PANEL WINDOWS MALWARE SCANNER v1"
    Write-Host "============================================"
    Write-Host "  Scan path: $Root"
    Write-Host "  Max file size: $MaxFileMB MB"
    Write-Host "  OS: $OsCaption $OsVersion"
    Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"
}

Write-Section "[0/12] Indexing files"
$Files = @(Get-SafeFiles -RootPath $Root)
Write-Ok "Indexed $($Files.Count) text-like files"

Write-Section "[1/12] XOR dropper pattern"
Search-Files `
    -Check "XOR dropper pattern" `
    -Pattern "String\.fromCharCode\s*\(\s*a\s*\[\s*i\s*\]\s*\^\s*k\s*\)|String\.fromCharCode\s*\(\s*[A-Za-z0-9_$]+\s*\[\s*[A-Za-z0-9_$]+\s*\]\s*\^\s*[A-Za-z0-9_$]+\s*\)" `
    -Severity "High" `
    -Files ($Files | Where-Object { $_.Extension -ieq ".js" }) `
    -Advice "Treat this as active or staged JavaScript loader code. Remove from clean backup after triage."

Write-Section "[2/12] Attacker identifiers and mutexes"
Search-Files `
    -Check "Attacker identifiers" `
    -Pattern "(?i)\b(bertjj|bertjjgg|bertjjcfxre|miauss|miausas|fivems\.lt|9ns1\.com|VB8mdVjrzd|blum-panel|warden-panel|cipher-panel|gfxpanel|ggWP)\b" `
    -Severity "High" `
    -Files ($Files | Where-Object { $_.Extension -in @(".js", ".lua", ".cfg") -or $_.Name -ieq "server.cfg" }) `
    -Advice "Known Blum/Warden/GFX strings were found in executable server files."

Write-Section "[3/12] txAdmin tampering indicators"
Search-Files `
    -Check "txAdmin backdoor indicators" `
    -Pattern "RESOURCE_EXCLUDE|isExcludedResource|onServerResourceFail|helpEmptyCode|JohnsUrUncle|txadmin:js_create" `
    -Severity "High" `
    -Files ($Files | Where-Object { $_.Extension -ieq ".lua" -or $_.Extension -ieq ".json" }) `
    -Advice "Restore txAdmin files from an official release and check txAdmin admin accounts."

Write-Section "[4/12] txAdmin backdoor admin account"
$AdminFiles = @($Files | Where-Object {
    $_.Extension -ieq ".json" -and
    ($_.Name -ieq "admins.json" -or $_.FullName -match "(?i)[\\/]txData[\\/]|[\\/]txAdmin[\\/]")
})
Search-Files `
    -Check "Backdoor admin account JohnsUrUncle" `
    -Pattern "(?i)JohnsUrUncle" `
    -Severity "High" `
    -Files $AdminFiles `
    -Advice "Delete this txAdmin admin account if present, then rotate txAdmin credentials and tokens."

Write-Section "[5/12] txAdmin monitor files"
$MonitorFiles = @($Files | Where-Object {
    $_.Extension -ieq ".lua" -and $_.FullName -match "(?i)[\\/]monitor[\\/]" -and
    $_.Name -in @("cl_playerlist.lua", "sv_main.lua", "sv_resources.lua")
})
$MonitorFindingCount = 0
foreach ($MonitorFile in $MonitorFiles) {
    if ($MonitorFile.Name -ieq "cl_playerlist.lua") {
        $Pattern = "helpEmptyCode"
        $Label = "txAdmin cl_playerlist.lua client RCE"
    } elseif ($MonitorFile.Name -ieq "sv_main.lua") {
        $Pattern = "RESOURCE_EXCLUDE|isExcludedResource"
        $Label = "txAdmin sv_main.lua resource cloaking"
    } else {
        $Pattern = "onServerResourceFail"
        $Label = "txAdmin sv_resources.lua server RCE"
    }

    $Hits = Select-String -LiteralPath $MonitorFile.FullName -Pattern $Pattern -ErrorAction SilentlyContinue
    foreach ($Hit in $Hits) {
        Add-Finding -Severity "High" -Check $Label -File $Hit.Path -Line $Hit.LineNumber -Evidence $Hit.Line -Advice "Replace this file from the official txAdmin release."
        $MonitorFindingCount++
    }
}
if ($MonitorFiles.Count -eq 0) {
    Write-WarnLine "No txAdmin monitor files found under scan path."
} elseif ($MonitorFindingCount -eq 0) {
    Write-Ok "Known txAdmin monitor backdoors not found"
}

Write-Section "[6/12] Suspicious dropper filenames in suspicious paths"
$SuspiciousPathPattern = "(?i)[\\/](server|modules|middleware|dist)[\\/]|[\\/]node_modules[\\/]\.cache[\\/]"
$DropperFileHits = @($Files | Where-Object {
    ($DropperNames -contains ($_.Name.ToLowerInvariant())) -and
    ($_.FullName -match $SuspiciousPathPattern)
})
foreach ($File in $DropperFileHits) {
    $ContentHit = Select-String -LiteralPath $File.FullName -Pattern "fromCharCode|eval\s*\(" -List -ErrorAction SilentlyContinue
    if ($ContentHit) {
        Add-Finding -Severity "High" -Check "Known dropper filename with executable loader markers" -File $File.FullName -Line $ContentHit.LineNumber -Evidence $ContentHit.Line -Advice "Inspect this resource and restore from a clean copy."
    } else {
        Add-Finding -Severity "Medium" -Check "Known dropper filename in suspicious path" -File $File.FullName -Evidence $File.Name -Advice "Filename matches known Blum placement names. Review manually."
    }
}
if ($DropperFileHits.Count -eq 0) {
    Write-Ok "No suspicious known dropper filenames found"
}

Write-Section "[7/12] C2 domains in code"
$EscapedDomains = $C2Domains | ForEach-Object { [regex]::Escape($_) }
$DomainPattern = "(?i)(" + ($EscapedDomains -join "|") + ")"
Search-Files `
    -Check "C2 domain reference" `
    -Pattern $DomainPattern `
    -Severity "High" `
    -Files ($Files | Where-Object { $_.Extension -in @(".js", ".lua", ".cfg") -or $_.Name -ieq "server.cfg" }) `
    -Advice "Block egress to the domain and inspect the containing resource."

Write-Section "[8/12] Obfuscation, Luraph, and loader markers"
Search-Files `
    -Check "Obfuscation or loader marker" `
    -Pattern "decompressFromUTF16|\\u15E1|aga\[0x|UARZT6\[|Luraph Obfuscator|installed_notices|vm'\)\.runInThisContext|devJJ|nullJJ|zXeAHJJ|roleplayJJ|cityJJ|mafiaJJ|gangJJ|anonJJ|panelJJ|blumJJ|miaussJJ" `
    -Severity "Medium" `
    -Files ($Files | Where-Object { $_.Extension -in @(".js", ".lua") }) `
    -Advice "This may indicate obfuscated Lua/JavaScript loader code. Review in context."

Write-Section "[9/12] fxmanifest.lua suspicious entries"
$ManifestFiles = @($Files | Where-Object { $_.Name -ieq "fxmanifest.lua" -or $_.Name -ieq "__resource.lua" })
Search-Files `
    -Check "Suspicious manifest entry" `
    -Pattern "(?i)node_modules[\\/]\.|\.cache[\\/]|middleware[\\/]|dist[\\/].*\.js|babel_config|jest_mock|mock_data|webpack_bundle|env_backup|cache_old|build_cache|vite_temp|eslint_rc|jest_setup|sync_worker|hook_system|patch_update" `
    -Severity "Medium" `
    -Files $ManifestFiles `
    -Advice "Blum payloads commonly add hidden JS paths to resource manifests."

Write-Section "[10/12] Discord webhook IOC"
Search-Files `
    -Check "Blum Discord webhook IOC" `
    -Pattern "1470175544682217685|pe8DNcnZCjKPlKF24tk72R" `
    -Severity "High" `
    -Files ($Files | Where-Object { $_.Extension -in @(".js", ".lua") }) `
    -Advice "Webhook phone-home indicator found. Treat the resource as compromised."

Write-Section "[11/12] Known payload size ranges"
$AllCandidateFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object {
        $_.FullName -notmatch "[\\/]\.git[\\/]" -and
        $_.Extension.ToLowerInvariant() -in @(".js", ".lua", ".bin", ".txt")
    })
foreach ($File in $AllCandidateFiles) {
    $Size = [int64]$File.Length
    $Reason = $null
    if ($Size -ge (420 * $KB) -and $Size -le (470 * $KB) -and $File.Extension -ieq ".js") {
        $Reason = "size resembles JScrambler dropper payload"
    } elseif ($Size -ge (1600 * $KB) -and $Size -le (1650 * $KB) -and $File.Extension -ieq ".js") {
        $Reason = "size resembles live C2 replicator payload"
    } elseif ($Size -ge (40 * $KB) -and $Size -le (46 * $KB) -and $File.Extension -ieq ".js") {
        $Reason = "size resembles XOR yarn/webpack dropper variant"
    } elseif ($Size -ge (60 * $KB) -and $Size -le (67 * $KB) -and $File.Extension -ieq ".lua") {
        $Reason = "size resembles Luraph Lua payload"
    }

    if ($Reason) {
        Add-Finding -Severity "Low" -Check "Known payload size range" -File $File.FullName -Evidence "$Size bytes; $Reason" -Advice "Size alone is not proof. Search this file for the high-severity strings above."
    }
}
if (-not ($Findings | Where-Object { $_.check -eq "Known payload size range" })) {
    Write-Ok "No files matched known payload size ranges"
}

Write-Section "[12/12] Windows hosts and active connections"
$HostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
if (Test-Path -LiteralPath $HostsPath) {
    $HostsText = Get-Content -LiteralPath $HostsPath -Raw -ErrorAction SilentlyContinue
    foreach ($Domain in @("9ns1.com", "fivems.lt", "blum-panel.me", "warden-panel.me", "gfxpanel.org")) {
        if ($HostsText -match "(?im)^\s*(0\.0\.0\.0|127\.0\.0\.1|::1)\s+.*\b$([regex]::Escape($Domain))\b") {
            Write-Ok "hosts blocks $Domain"
        } else {
            Write-WarnLine "hosts does not block $Domain (advisory only, not an infection indicator)"
        }
    }
} else {
    Write-WarnLine "Windows hosts file not found at $HostsPath (advisory only)"
}

if (-not $NoNetstat) {
    $ConnectionHits = @()
    $Connections = Get-NetTCPConnection -ErrorAction SilentlyContinue
    if ($Connections) {
        foreach ($Connection in $Connections) {
            if ($DirectIps -contains $Connection.RemoteAddress) {
                $ConnectionHits += [pscustomobject]@{
                    RemoteAddress = $Connection.RemoteAddress
                    RemotePort    = $Connection.RemotePort
                    State         = $Connection.State
                    OwningProcess = $Connection.OwningProcess
                }
            }
        }
    } else {
        $Netstat = netstat -ano 2>$null
        foreach ($Line in $Netstat) {
            foreach ($Ip in $DirectIps) {
                if ($Line -match ([regex]::Escape($Ip))) {
                    $ConnectionHits += [pscustomobject]@{
                        RemoteAddress = $Ip
                        RemotePort    = ""
                        State         = "netstat"
                        OwningProcess = ($Line -replace "\s+", " ").Trim()
                    }
                }
            }
        }
    }

    foreach ($Hit in $ConnectionHits) {
        $ProcessLabel = "PID=$($Hit.OwningProcess)"
        if ($Hit.OwningProcess -match "^\d+$") {
            $Process = Get-Process -Id ([int]$Hit.OwningProcess) -ErrorAction SilentlyContinue
            if ($Process) {
                $ProcessLabel = "$($Process.ProcessName) PID=$($Hit.OwningProcess)"
            }
        }
        Add-Finding -Severity "High" -Check "Active connection to known direct C2/file server IP" -Evidence "$($Hit.RemoteAddress):$($Hit.RemotePort) $($Hit.State) $ProcessLabel" -Advice "Identify the process and isolate the server before cleanup."
    }
    if ($ConnectionHits.Count -eq 0) {
        Write-Ok "No active TCP connections to known direct C2 IPs"
    }
}

$HighCount = @($Findings | Where-Object { $_.severity -eq "High" }).Count
$MediumCount = @($Findings | Where-Object { $_.severity -eq "Medium" }).Count
$LowCount = @($Findings | Where-Object { $_.severity -eq "Low" }).Count

if ($Json) {
    [pscustomobject]@{
        scanner       = "blum-panel-windows-scanner"
        version       = "1"
        path          = $Root
        generated_utc = (Get-Date).ToUniversalTime().ToString("o")
        summary       = [pscustomobject]@{
            high   = $HighCount
            medium = $MediumCount
            low    = $LowCount
            total  = $Findings.Count
        }
        findings      = $Findings
    } | ConvertTo-Json -Depth 5
} else {
    Write-Host ""
    Write-Host "============================================"
    Write-Host " SUMMARY"
    Write-Host "============================================"
    Write-Host " High:   $HighCount"
    Write-Host " Medium: $MediumCount"
    Write-Host " Low:    $LowCount"
    Write-Host " Total:  $($Findings.Count)"
    Write-Host ""
    if ($HighCount -gt 0) {
        Write-Host "Result: HIGH-RISK indicators found. Treat the server as compromised until proven otherwise." -ForegroundColor Red
        Write-Host "Next: isolate, preserve evidence, restore txAdmin/resource files from clean sources, and rotate credentials." -ForegroundColor Red
    } elseif (($MediumCount + $LowCount) -gt 0) {
        Write-Host "Result: Review findings. No high-confidence indicators were found by this script." -ForegroundColor Yellow
    } else {
        Write-Host "Result: No known Blum Panel indicators found." -ForegroundColor Green
    }
    Write-Host "============================================"
}

if ($HighCount -gt 0) { exit 2 }
if (($MediumCount + $LowCount) -gt 0) { exit 1 }
exit 0
