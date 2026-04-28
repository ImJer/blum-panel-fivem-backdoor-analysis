#requires -Version 5.1
<#
BLUM PANEL C2 BLOCKER FOR WINDOWS v1

Windows Server 2019 compatible helper to block known Blum Panel / Warden Panel /
GFX Panel C2 infrastructure.

Default mode is dry-run. Add -Apply to make changes.

Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\block_c2_windows.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File .\block_c2_windows.ps1 -Apply
  powershell -NoProfile -ExecutionPolicy Bypass -File .\block_c2_windows.ps1 -Undo

What -Apply does:
  - Backs up C:\Windows\System32\drivers\etc\hosts
  - Adds 0.0.0.0 hosts entries for known C2 domains
  - Adds Windows Defender Firewall outbound block rules for direct attacker IPs

What -Undo does:
  - Removes firewall rules created by this script
  - Leaves hosts file entries in place; restore the timestamped backup manually if needed
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Apply,
    [switch]$Undo,
    [switch]$SkipHosts,
    [switch]$SkipFirewall
)

$ErrorActionPreference = "SilentlyContinue"

function Test-IsAdmin {
    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
    return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Cyan
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
    "gfxpanel.org",
    "kutingplays.com"
)

$DirectIps = @(
    "185.87.23.198",
    "185.80.128.35",
    "185.80.128.36",
    "185.80.130.168"
)

$RuleGroup = "Blum Panel C2 Block"
$HostsPath = Join-Path $env:SystemRoot "System32\drivers\etc\hosts"
$Mode = "DRY RUN"
if ($Undo) {
    $Mode = "UNDO"
} elseif ($Apply) {
    $Mode = "APPLY"
}

Write-Host ""
Write-Host "============================================"
Write-Host "  BLUM PANEL WINDOWS C2 BLOCKER v1"
Write-Host "============================================"
Write-Host "  Mode: $Mode"
Write-Host "  PowerShell: $($PSVersionTable.PSVersion)"

if (($Apply -or $Undo) -and -not (Test-IsAdmin)) {
    Write-Host ""
    Write-Host "This script must be run as Administrator to change hosts or firewall rules." -ForegroundColor Red
    Write-Host "Open PowerShell as Administrator and run it again." -ForegroundColor Red
    exit 3
}

if ($Undo) {
    Write-Step "[1/1] Removing firewall rules created by this script"
    $Rules = Get-NetFirewallRule -Group $RuleGroup -ErrorAction SilentlyContinue
    if ($Rules) {
        if ($PSCmdlet.ShouldProcess($RuleGroup, "Remove firewall rules")) {
            $Rules | Remove-NetFirewallRule
        }
        Write-Host "  Removed firewall rules in group: $RuleGroup" -ForegroundColor Green
    } else {
        Write-Host "  No firewall rules found in group: $RuleGroup" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Hosts entries are not removed automatically. Restore your hosts backup manually if required." -ForegroundColor Yellow
    exit 0
}

if (-not $Apply) {
    Write-Host ""
    Write-Host "Dry run only. Re-run with -Apply to make changes." -ForegroundColor Yellow
}

if (-not $SkipHosts) {
    Write-Step "[1/2] Hosts file domain blocking"
    if (-not (Test-Path -LiteralPath $HostsPath)) {
        Write-Host "  Hosts file not found: $HostsPath" -ForegroundColor Red
    } else {
        $HostsText = Get-Content -LiteralPath $HostsPath -Raw -ErrorAction SilentlyContinue
        $MissingDomains = @()
        foreach ($Domain in ($C2Domains | Sort-Object -Unique)) {
            if ($HostsText -notmatch "(?im)^\s*(0\.0\.0\.0|127\.0\.0\.1|::1)\s+.*\b$([regex]::Escape($Domain))\b") {
                $MissingDomains += $Domain
            }
        }

        if ($MissingDomains.Count -eq 0) {
            Write-Host "  All listed C2 domains already appear blocked in hosts." -ForegroundColor Green
        } else {
            Write-Host "  Domains to add: $($MissingDomains.Count)" -ForegroundColor Yellow
            foreach ($Domain in $MissingDomains) {
                Write-Host "    0.0.0.0 $Domain"
                Write-Host "    0.0.0.0 www.$Domain"
            }

            if ($Apply) {
                $BackupPath = "$HostsPath.blum-backup-$(Get-Date -Format yyyyMMddHHmmss)"
                try {
                    Copy-Item -LiteralPath $HostsPath -Destination $BackupPath -Force -ErrorAction Stop
                    $Lines = New-Object System.Collections.Generic.List[string]
                    $Lines.Add("") | Out-Null
                    $Lines.Add("# Blum Panel C2 block entries added $(Get-Date -Format s)") | Out-Null
                    foreach ($Domain in $MissingDomains) {
                        $Lines.Add("0.0.0.0 $Domain") | Out-Null
                        $Lines.Add("0.0.0.0 www.$Domain") | Out-Null
                    }
                    Add-Content -LiteralPath $HostsPath -Value $Lines -ErrorAction Stop
                    Write-Host "  Updated hosts. Backup: $BackupPath" -ForegroundColor Green
                } catch {
                    Write-Host "  Failed to update hosts: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    }
}

if (-not $SkipFirewall) {
    Write-Step "[2/2] Windows Defender Firewall direct IP blocking"
    foreach ($Ip in $DirectIps) {
        $RuleName = "Blum Panel C2 Block $Ip"
        $Existing = Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue
        if ($Existing) {
            Write-Host "  Exists: $RuleName" -ForegroundColor Green
            continue
        }

        if ($Apply) {
            try {
                New-NetFirewallRule `
                    -DisplayName $RuleName `
                    -Group $RuleGroup `
                    -Direction Outbound `
                    -Action Block `
                    -RemoteAddress $Ip `
                    -Profile Any `
                    -Enabled True `
                    -ErrorAction Stop | Out-Null
                Write-Host "  Added: $RuleName" -ForegroundColor Green
            } catch {
                Write-Host "  Failed to add ${RuleName}: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            Write-Host "  Would add outbound block rule for $Ip"
        }
    }
}

Write-Host ""
Write-Host "============================================"
Write-Host " SUMMARY"
Write-Host "============================================"
if ($Apply) {
    Write-Host "Applied Windows hosts and firewall protections for known C2 infrastructure." -ForegroundColor Green
    Write-Host "Flush DNS cache with: ipconfig /flushdns"
} else {
    Write-Host "No changes made. Re-run with -Apply to block listed domains and direct IPs." -ForegroundColor Yellow
}
Write-Host "Firewall rule group: $RuleGroup"
Write-Host "============================================"
