#!/bin/bash
# ============================================================
# BLUM PANEL DEEP PROBE v3 — Origin server + Bundle + Cipher
# Run: bash blum_probe_v3.sh 2>&1 | tee probe_v3_results.txt
# ============================================================

cd ~/blum-probe

echo "=========================================="
echo "1. ORIGIN SERVER 185.87.23.198 (DEEP)"
echo "=========================================="

# The origin leaked from Cloudflare redirects. 
# Try multiple ports and protocols
for port in 80 443 3000 5000 8080 8443 4000; do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "http://185.87.23.198:$port/" --connect-timeout 3 2>/dev/null)
    echo "HTTP  185.87.23.198:$port → $result"
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "https://185.87.23.198:$port/" -k --connect-timeout 3 2>/dev/null)
    echo "HTTPS 185.87.23.198:$port → $result"
done

# Try connecting WITH the Host header (might bypass Cloudflare requirement)
echo ""
echo "--- With Host headers ---"
for host in 9ns1.com fivems.lt blum-panel.me; do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "http://185.87.23.198:5000/" -H "Host: $host" --connect-timeout 3 2>/dev/null)
    echo "185.87.23.198:5000 Host:$host → $result"
done

# Check nmap if available
echo ""
echo "--- Port scan (top ports) ---"
if command -v nmap &>/dev/null; then
    nmap -Pn -sT --top-ports 20 185.87.23.198 2>/dev/null | grep -E "open|closed|filtered"
else
    echo "nmap not available, trying nc..."
    for port in 22 80 443 3000 5000 8080 8443; do
        (echo >/dev/tcp/185.87.23.198/$port) 2>/dev/null && echo "Port $port: OPEN" || echo "Port $port: closed/filtered"
    done
fi

# Reverse DNS
echo ""
echo "--- Reverse DNS ---"
dig -x 185.87.23.198 +short 2>/dev/null
host 185.87.23.198 2>/dev/null

echo ""
echo "=========================================="
echo "2. FILE HOST 185.80.128.35 (ROOT PAGE)"
echo "=========================================="

# Earlier it returned HTTP 200 with 10KB on root — grab it
curl -s "http://185.80.128.35/" -o filehost_index.html -w "Root: HTTP %{http_code}, %{size_download} bytes\n"
echo "--- First 100 lines ---"
head -100 filehost_index.html
echo ""

# Try other interesting paths
for p in /uploads /uploads/ /api /panel /admin /login /resources; do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "http://185.80.128.35$p" --connect-timeout 3 2>/dev/null)
    echo "185.80.128.35$p → $result"
done

echo ""
echo "=========================================="
echo "3. CIPHER-PANEL.ME DEEP PROBE"
echo "=========================================="

# Cipher is the predecessor panel, Blum integrates with it
curl -s "https://cipher-panel.me/" -o cipher_index.html -w "Root: HTTP %{http_code}, %{size_download} bytes, redirect to %{redirect_url}\n" -L
head -50 cipher_index.html
echo ""

curl -s "https://cipher-panel.me/en/" -o cipher_en.html -w "/en/: HTTP %{http_code}, %{size_download} bytes\n" -L

# Cipher endpoints from known intel
for p in /_i/i /_i/r.php "/_i/r.php?to=0" /api /login /en/agreement /discord /secure_area; do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "https://cipher-panel.me$p" --connect-timeout 3 2>/dev/null)
    echo "cipher-panel.me$p → $result"
done

# DNS
dig cipher-panel.me +short
dig cipher-panel.me NS +short 2>/dev/null

# WHOIS
whois cipher-panel.me 2>/dev/null | grep -iE "registrant|admin|name.server|creation|expir|registrar|email|country" | head -15

echo ""
echo "=========================================="
echo "4. BLUM-PANEL.COM DEEP PROBE"
echo "=========================================="

dig blum-panel.com A +short
dig blum-panel.com NS +short 2>/dev/null
curl -s "https://blum-panel.com/" -o blum_com_index.html -w "Root: HTTP %{http_code}, %{size_download} bytes\n" -L
head -30 blum_com_index.html
echo ""

curl -s "https://blum-panel.com/en/agreement" -o blum_agreement.html -w "Agreement: HTTP %{http_code}, %{size_download} bytes\n" -L
head -100 blum_agreement.html
echo ""

curl -s "https://blum-panel.com/discord" -o /dev/null -w "Discord redirect: HTTP %{http_code}, redirect to %{redirect_url}\n" -L

whois blum-panel.com 2>/dev/null | grep -iE "registrant|admin|name.server|creation|expir|registrar|email|country" | head -15

echo ""
echo "=========================================="
echo "5. BLUM-PANEL.ME DEEP PROBE"
echo "=========================================="

curl -s "https://blum-panel.me/" -o blum_me_index.html -w "Root: HTTP %{http_code}, %{size_download} bytes\n"
head -50 blum_me_index.html
echo ""

# Check if blum-panel.me has same panel or different
grep -oP 'src="[^"]*"' blum_me_index.html 2>/dev/null | head -5
grep -oP 'href="[^"]*\.css"' blum_me_index.html 2>/dev/null | head -5

whois blum-panel.me 2>/dev/null | grep -iE "registrant|admin|name.server|creation|expir|registrar|email|country" | head -15

echo ""
echo "=========================================="
echo "6. BUNDLE.JS DEEP ANALYSIS"
echo "=========================================="

# Extract everything interesting from the 1.97MB React bundle
BUNDLE=~/blum-probe/9ns1_bundle.js

echo "--- All Socket.IO events (complete) ---"
grep -oP '"(admin|discord|server|fs|command|webrtc|screenshare|heartbeat|register|serverInfo)[^"]*"' $BUNDLE 2>/dev/null | sort -u

echo ""
echo "--- All HTTP endpoints ---"
grep -oP '"/(api|auth|ext|download|upload|webhook|socket|resource)[^"]*"' $BUNDLE 2>/dev/null | sort -u

echo ""
echo "--- All external URLs ---"
grep -oP 'https?://[a-zA-Z0-9._:/-]+' $BUNDLE 2>/dev/null | sort -u

echo ""
echo "--- IP addresses ---"
grep -oP '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b' $BUNDLE 2>/dev/null | sort -u

echo ""
echo "--- Discord references ---"
grep -oP 'discord[^"]*' $BUNDLE 2>/dev/null | sort -u | head -30

echo ""
echo "--- Crypto/payment references ---"
grep -oiP '(bitcoin|btc|ethereum|eth|crypto|wallet|payment|price|coin|usdt|litecoin|monero)[^"]*' $BUNDLE 2>/dev/null | sort -u | head -20

echo ""
echo "--- Auth/session/JWT references ---"
grep -oP '"(auth|login|register|session|jwt|token|cookie|password|credential|apiKey|api_key)[^"]*"' $BUNDLE 2>/dev/null | sort -u | head -20

echo ""
echo "--- Cipher-panel references ---"
grep -oP 'cipher[^"]*' $BUNDLE 2>/dev/null | sort -u

echo ""
echo "--- Database/storage references ---"
grep -oiP '(mongodb|mysql|postgres|redis|sqlite|database|collection|mongoose)[^"]*' $BUNDLE 2>/dev/null | sort -u | head -10

echo ""
echo "--- Error messages (operational intel) ---"
grep -oP '"(Error|Failed|Cannot|Unable|Invalid|Unauthorized|Forbidden)[^"]{5,80}"' $BUNDLE 2>/dev/null | sort -u | head -30

echo ""
echo "--- Panel feature strings ---"
grep -oP '"(lockdown|payload|inject|infect|replicat|backdoor|exploit|keylog|steal|dump|download-resource|screenshare|stream)[^"]*"' $BUNDLE 2>/dev/null | sort -u

echo ""
echo "=========================================="
echo "7. EXTENDED API KEY SCAN"
echo "=========================================="

# Test more keys including those found in bundle
for key in panel blum miauss bert zXeAH cipher admin hack root server \
           free premium pro vip gold reseller partner affiliate \
           crack hack0r skid script kiddie leet elite \
           john uncle JohnsUrUncle txadmin monitor \
           luna nova star moon shadow dark light fire ice \
           alpha beta gamma omega sigma \
           fr de uk us es ru nl pl tr br; do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "https://9ns1.com/${key}JJ" -H "User-Agent: node" --connect-timeout 2 2>/dev/null)
    code=$(echo $result | cut -d: -f1)
    size=$(echo $result | cut -d: -f2)
    if [ "$code" = "200" ] && [ "$size" -gt 100 ]; then
        echo "ACTIVE: ${key}JJ ($size bytes)"
    fi
done

echo ""
echo "=========================================="
echo "8. DISCORD INTELLIGENCE"
echo "=========================================="

# Check both Discord invites
echo "--- VB8mdVjrzd (Blum malware invite) ---"
curl -s "https://discord.com/api/v10/invites/VB8mdVjrzd?with_counts=true" 2>/dev/null | python3 -m json.tool 2>/dev/null

echo ""
echo "--- ciphercorp (Cipher Discord) ---"
curl -s "https://discord.com/api/v10/invites/ciphercorp?with_counts=true" 2>/dev/null | python3 -m json.tool 2>/dev/null

echo ""
echo "=========================================="
echo "9. CERT TRANSPARENCY LOGS"
echo "=========================================="

for domain in 9ns1.com fivems.lt blum-panel.me blum-panel.com cipher-panel.me; do
    echo "--- $domain ---"
    curl -s "https://crt.sh/?q=$domain&output=json" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    seen = set()
    for cert in sorted(data, key=lambda x: x.get('id', 0)):
        cn = cert.get('common_name', '')
        na = cert.get('name_value', '').replace('\n', ', ')
        nb = cert.get('not_before', '')[:10]
        key = f'{cn}|{na}'
        if key not in seen:
            seen.add(key)
            print(f'  CN={cn}  SAN={na}  NotBefore={nb}')
except: pass
" 2>/dev/null
    echo ""
done

echo ""
echo "=========================================="
echo "10. PAYLOAD FILE HASHES & SIZES"
echo "=========================================="

for f in ~/blum-probe/9ns1_*.txt ~/blum-probe/9ns1_*.js; do
    [ -f "$f" ] || continue
    size=$(wc -c < "$f")
    [ "$size" -lt 10 ] && continue
    md5=$(md5sum "$f" | cut -d' ' -f1)
    sha256=$(sha256sum "$f" | cut -d' ' -f1)
    fname=$(basename "$f")
    echo "$fname:"
    echo "  Size: $size  MD5: $md5"
    echo "  SHA256: $sha256"
    head -c 60 "$f" | cat -v
    echo ""
    echo ""
done

echo ""
echo "=========================================="
echo "PROBE v3 COMPLETE"
echo "=========================================="
echo ""
echo "KEY FILES TO CHECK:"
echo "  1. ~/blum-probe/9ns1_bundle.js (1.97MB - panel frontend)"
echo "  2. ~/blum-probe/filehost_index.html (file server root)"  
echo "  3. ~/blum-probe/cipher_index.html (cipher panel)"
echo "  4. ~/blum-probe/blum_agreement.html (terms of service)"
echo "  5. ~/blum-probe/blum_me_index.html (original panel)"
echo "  6. This probe_v3_results.txt output"
