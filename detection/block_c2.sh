#!/bin/bash
# ============================================================================
# BLUM PANEL C2 BLOCKER v3 — FIXED
# ============================================================================
# Changes from v2:
#   - Uses REJECT instead of DROP (prevents server hitching from timeouts)
#   - Checks for Cloudflare/shared IPs before blocking
#   - Only blocks OUTPUT+FORWARD (not INPUT — C2 can't initiate to you anyway)
#   - Skips IPs in known CDN ranges to avoid breaking legitimate traffic
# ============================================================================

set -e

echo "============================================"
echo " BLUM PANEL C2 BLOCKER v3"
echo "============================================"
echo ""

# First: remove ALL old v2 rules
echo "[0/4] Removing old C2 DROP rules..."
iptables-save | grep -c "C2" 2>/dev/null && {
    # Remove all old C2 rules from all chains
    for chain in INPUT OUTPUT FORWARD; do
        while iptables -L "$chain" -n --line-numbers 2>/dev/null | grep -q "C2"; do
            linenum=$(iptables -L "$chain" -n --line-numbers | grep "C2" | head -1 | awk '{print $1}')
            iptables -D "$chain" "$linenum"
        done
    done
    echo "  Removed old rules."
} || echo "  No old rules found."

echo ""

C2_DOMAINS=(
    "fivems.lt"
    "9ns1.com"
    "0xchitado.com"
    "2312321321321213.com"
    "2ns3.net"
    "5mscripts.net"
    "bhlool.com"
    "bybonvieux.com"
    "fivemgtax.com"
    "flowleakz.org"
    "giithub.net"
    "iwantaticket.org"
    "jking.lt"
    "kutingplays.com"
    "l00x.org"
    "monloox.com"
    "noanimeisgay.com"
    "ryenz.net"
    "spacedev.fr"
    "trezz.org"
    "z1lly.org"
    "warden-panel.me"
    "2nit32.com"
    "useer.it.com"
    "wsichkidolu.com"
)

# Known CDN/shared hosting ranges to SKIP (would break legitimate traffic)
# Cloudflare: 104.16.0.0/12, 172.64.0.0/13, 173.245.48.0/20, 103.21.244.0/22, 
#             103.22.200.0/22, 103.31.4.0/22, 141.101.64.0/18, 108.162.192.0/18,
#             190.93.240.0/20, 188.114.96.0/20, 197.234.240.0/22, 198.41.128.0/17,
#             162.158.0.0/15, 131.0.72.0/22
is_cdn_ip() {
    local ip="$1"
    local IFS='.'
    read -r a b c d <<< "$ip"
    
    # Cloudflare ranges (most common shared IPs)
    [[ $a -eq 104 && $b -ge 16 && $b -le 31 ]] && return 0
    [[ $a -eq 172 && $b -ge 64 && $b -le 71 ]] && return 0
    [[ $a -eq 173 && $b -eq 245 ]] && return 0
    [[ $a -eq 103 && $b -eq 21 ]] && return 0
    [[ $a -eq 103 && $b -eq 22 ]] && return 0
    [[ $a -eq 103 && $b -eq 31 ]] && return 0
    [[ $a -eq 141 && $b -eq 101 ]] && return 0
    [[ $a -eq 108 && $b -eq 162 ]] && return 0
    [[ $a -eq 188 && $b -eq 114 ]] && return 0
    [[ $a -eq 162 && $b -ge 158 && $b -le 159 ]] && return 0
    [[ $a -eq 198 && $b -eq 41 ]] && return 0
    [[ $a -eq 131 && $b -eq 0 ]] && return 0
    
    # Akamai, Fastly, AWS CloudFront — too broad to list, but these are the big ones
    # If you're still having issues, add your specific IP ranges here
    
    return 1
}

echo "[1/4] Resolving domains and checking for shared IPs..."
echo ""

BLOCKED=0
SKIPPED=0
DEAD=0

for domain in "${C2_DOMAINS[@]}"; do
    IPS=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    
    if [ -z "$IPS" ]; then
        echo "  [~] $domain — dead/unresolvable (hosts file only)"
        DEAD=$((DEAD + 1))
    else
        for ip in $IPS; do
            if is_cdn_ip "$ip"; then
                echo "  [!] SKIPPED: $domain → $ip (CDN/shared IP — blocking would break other traffic)"
                SKIPPED=$((SKIPPED + 1))
            else
                # OUTPUT — stops server from calling C2 (REJECT = instant fail, no timeout)
                iptables -C OUTPUT -d "$ip" -j REJECT --reject-with tcp-reset 2>/dev/null || \
                    iptables -A OUTPUT -d "$ip" -j REJECT --reject-with tcp-reset -m comment --comment "C2-OUT:$domain"

                # FORWARD outbound — stops Docker containers from reaching C2
                iptables -C FORWARD -d "$ip" -j REJECT --reject-with tcp-reset 2>/dev/null || \
                    iptables -A FORWARD -d "$ip" -j REJECT --reject-with tcp-reset -m comment --comment "C2-FWD:$domain"

                echo "  [+] BLOCKED: $domain → $ip (REJECT — instant fail)"
                BLOCKED=$((BLOCKED + 1))
            fi
        done
    fi
done

echo ""
echo "[2/4] Updating /etc/hosts..."

# Backup
cp /etc/hosts "/etc/hosts.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

for domain in "${C2_DOMAINS[@]}"; do
    if ! grep -q "$domain" /etc/hosts 2>/dev/null; then
        echo "0.0.0.0 $domain" >> /etc/hosts
        echo "0.0.0.0 www.$domain" >> /etc/hosts
    fi
done
echo "  Done."

echo ""
echo "[3/4] Persisting rules..."
netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4 2>/dev/null || echo "  [!] Could not persist — run manually: iptables-save > /etc/iptables/rules.v4"

echo ""
echo "[4/4] Verifying no player-facing ports are blocked..."
echo ""

# Check that FiveM ports are clean (30120 TCP/UDP default)
FIVEM_BLOCKED=$(iptables -L -n | grep -E "30120|30110" | grep -c "DROP\|REJECT" 2>/dev/null || echo "0")
if [ "$FIVEM_BLOCKED" -gt 0 ]; then
    echo "  [!!!] WARNING: Found rules affecting FiveM ports! Check with:"
    echo "        iptables -L -n --line-numbers | grep 3012"
else
    echo "  [OK] No rules touching FiveM ports (30120/30110)."
fi

echo ""
echo "============================================"
echo " SUMMARY"
echo "============================================"
echo " Domains:     ${#C2_DOMAINS[@]}"
echo " IPs blocked: $BLOCKED (REJECT — no timeout)"
echo " CDN skipped: $SKIPPED (would break traffic)"
echo " Dead/unresolvable: $DEAD (hosts file only)"
echo ""
echo " CHANGES FROM v2:"
echo "   ✓ REJECT replaces DROP (no more hitching)"
echo "   ✓ CDN/shared IPs skipped (no more conn issues)"
echo "   ✓ Removed INPUT rules (unnecessary)"
echo "   ✓ Old v2 rules cleaned up"
echo ""
echo " Verify:  iptables -L -n | grep C2"
echo " Undo:    iptables-save | grep -v C2 | iptables-restore"
echo "============================================"
