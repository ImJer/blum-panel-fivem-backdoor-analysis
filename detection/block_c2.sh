#!/bin/bash
# ============================================================================
# BLUM PANEL / BERTJJ C2 DOMAIN BLOCKER v2
# ============================================================================
# Blocks all known C2 domains at the firewall level.
# Blocks OUTPUT (server→C2), INPUT (C2→server), and FORWARD (Docker traffic).
# FORWARD is critical for Pterodactyl/Docker containers.
# Run as root on the host machine.
# ============================================================================

echo "============================================"
echo " BLOCKING ALL KNOWN C2 DOMAINS"
echo " Inbound + Outbound + Forward"
echo "============================================"

C2_DOMAINS=(
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
    "fivems.lt"
)

echo ""
echo "[1/3] Resolving domains and blocking via iptables..."
echo ""

BLOCKED=0
FAILED=0

for domain in "${C2_DOMAINS[@]}"; do
    IPS=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    
    if [ -z "$IPS" ]; then
        echo "  [!] $domain — no DNS resolution (may be dead)"
        FAILED=$((FAILED + 1))
    else
        for ip in $IPS; do
            # Outbound — stops server from calling C2
            iptables -C OUTPUT -d "$ip" -j DROP 2>/dev/null
            if [ $? -ne 0 ]; then
                iptables -A OUTPUT -d "$ip" -j DROP -m comment --comment "C2-OUT: $domain"
            fi

            # Inbound — stops C2 from connecting to server
            iptables -C INPUT -s "$ip" -j DROP 2>/dev/null
            if [ $? -ne 0 ]; then
                iptables -A INPUT -s "$ip" -j DROP -m comment --comment "C2-IN: $domain"
            fi

            # Forward outbound — stops Docker containers from reaching C2
            iptables -C FORWARD -d "$ip" -j DROP 2>/dev/null
            if [ $? -ne 0 ]; then
                iptables -A FORWARD -d "$ip" -j DROP -m comment --comment "C2-FWD: $domain"
            fi

            # Forward inbound — stops C2 from reaching Docker containers
            iptables -C FORWARD -s "$ip" -j DROP 2>/dev/null
            if [ $? -ne 0 ]; then
                iptables -A FORWARD -s "$ip" -j DROP -m comment --comment "C2-FWD-IN: $domain"
            fi

            echo "  [+] BLOCKED: $domain → $ip (in+out+forward)"
            BLOCKED=$((BLOCKED + 1))
        done
    fi
done

echo ""
echo "[2/3] Adding domains to /etc/hosts..."
echo ""

cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d%H%M%S)

for domain in "${C2_DOMAINS[@]}"; do
    if ! grep -q "$domain" /etc/hosts 2>/dev/null; then
        echo "0.0.0.0 $domain" >> /etc/hosts
        echo "0.0.0.0 www.$domain" >> /etc/hosts
        echo "  [+] Added: $domain"
    else
        echo "  [=] Already blocked: $domain"
    fi
done

echo ""
echo "[3/3] Persisting rules across reboots..."
echo ""

apt install iptables-persistent -y 2>/dev/null
netfilter-persistent save 2>/dev/null

echo ""
echo "============================================"
echo " SUMMARY"
echo "============================================"
echo " Domains processed: ${#C2_DOMAINS[@]}"
echo " IPs blocked:       $BLOCKED (x4 rules each)"
echo " Unresolvable:      $FAILED"
echo " /etc/hosts:        updated"
echo " iptables:          persisted"
echo ""
echo " Chains blocked:"
echo "   OUTPUT  — server cannot call C2"
echo "   INPUT   — C2 cannot connect to server"
echo "   FORWARD — Docker containers blocked both ways"
echo ""
echo " Verify:  iptables -L -n | grep C2"
echo ""
echo " To undo: iptables-save | grep -v C2 | iptables-restore"
echo "          Restore /etc/hosts from backup"
echo "============================================"
