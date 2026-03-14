#!/bin/bash
# ============================================================
# BLUM PANEL DEEP PROBE v2
# Run on your Vultr box: bash blum_probe_v2.sh 2>&1 | tee probe_results.txt
# ============================================================

cd ~/blum-probe 2>/dev/null || mkdir -p ~/blum-probe && cd ~/blum-probe

echo "=========================================="
echo "1. CAPTURE UNKNOWN PAYLOADS FROM 9ns1.com"
echo "=========================================="

# /test and /dev are 65KB and 64KB — smaller operator payloads
curl -s "https://9ns1.com/test" -H "User-Agent: node" -o 9ns1_test.txt -w "/test: HTTP %{http_code}, %{size_download} bytes\n"
curl -s "https://9ns1.com/dev" -H "User-Agent: node" -o 9ns1_dev.txt -w "/dev:  HTTP %{http_code}, %{size_download} bytes\n"
curl -s "https://9ns1.com/null" -H "User-Agent: node" -o 9ns1_null.txt -w "/null: HTTP %{http_code}, %{size_download} bytes\n"

# zXeAH variants (the second operator's endpoints)
curl -s "https://9ns1.com/zXeAHJJ" -H "User-Agent: node" -o 9ns1_zXeAHJJ.txt -w "/zXeAHJJ: HTTP %{http_code}, %{size_download} bytes\n"
curl -s "https://9ns1.com/zXeAHJJgg" -H "User-Agent: node" -o 9ns1_zXeAHJJgg.txt -w "/zXeAHJJgg: HTTP %{http_code}, %{size_download} bytes\n"
curl -s "https://9ns1.com/zXeAHJJcfxre" -H "User-Agent: node" -o 9ns1_zXeAHJJcfxre.txt -w "/zXeAHJJcfxre: HTTP %{http_code}, %{size_download} bytes\n"

# /ext dropper variants per apiKey
curl -s "https://9ns1.com/ext/zXeAH" -H "User-Agent: node" -o 9ns1_ext_zXeAH.txt -w "/ext/zXeAH: HTTP %{http_code}, %{size_download} bytes\n"
curl -s "https://9ns1.com/ext/dev" -H "User-Agent: node" -o 9ns1_ext_dev.txt -w "/ext/dev: HTTP %{http_code}, %{size_download} bytes\n"
curl -s "https://9ns1.com/ext/test" -H "User-Agent: node" -o 9ns1_ext_test.txt -w "/ext/test: HTTP %{http_code}, %{size_download} bytes\n"
curl -s "https://9ns1.com/ext/null" -H "User-Agent: node" -o 9ns1_ext_null.txt -w "/ext/null: HTTP %{http_code}, %{size_download} bytes\n"

echo ""
echo "=========================================="
echo "2. FIVEMS.LT CROSS-CHECK"
echo "=========================================="

for path in test dev null testJJ devJJ nullJJ \
            zXeAHJJ zXeAHJJgg zXeAHJJcfxre \
            ext/zXeAH ext/dev ext/test ext/null \
            bertJJ bertJJgg bertJJcfxre ext/bert; do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "https://fivems.lt/$path" -H "User-Agent: node" --connect-timeout 5 2>/dev/null)
    code=$(echo $result | cut -d: -f1)
    size=$(echo $result | cut -d: -f2)
    if [ "$code" != "000" ]; then
        echo "fivems.lt/$path → HTTP $code ($size bytes)"
    fi
done

echo ""
echo "=========================================="
echo "3. BRUTE-FORCE API KEY DISCOVERY"
echo "=========================================="

# Common short names that operators might use
for key in admin root test dev null hack panel blum miauss bert zXeAH \
           main prod stage alpha beta gamma delta user1 user2 \
           free premium vip pro elite gold silver \
           server1 server2 fivem rp roleplay city mafia gang \
           anon anonymous guest demo trial sample; do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "https://9ns1.com/${key}JJ" -H "User-Agent: node" --connect-timeout 3 2>/dev/null)
    code=$(echo $result | cut -d: -f1)
    size=$(echo $result | cut -d: -f2)
    if [ "$code" = "200" ] && [ "$size" -gt 100 ]; then
        echo "FOUND: 9ns1.com/${key}JJ → HTTP $code ($size bytes)"
    fi
done

echo ""
echo "=========================================="
echo "4. PANEL FRONTEND + API RECON"
echo "=========================================="

# Grab the panel frontend
curl -s "https://9ns1.com/" -o 9ns1_index.html -w "/ (index): HTTP %{http_code}, %{size_download} bytes\n"

# Extract JS/CSS bundle URLs from index
echo "--- Frontend assets ---"
grep -oP 'src="[^"]*"' 9ns1_index.html | head -10
grep -oP 'href="[^"]*\.css"' 9ns1_index.html | head -5

# Grab the main JS bundle
JS_URL=$(grep -oP 'src="/assets/index-[^"]*\.js"' 9ns1_index.html | head -1 | grep -oP '/assets/[^"]+')
if [ -n "$JS_URL" ]; then
    echo "Fetching main bundle: $JS_URL"
    curl -s "https://9ns1.com${JS_URL}" -o 9ns1_bundle.js -w "Bundle: HTTP %{http_code}, %{size_download} bytes\n"
    
    # Extract API endpoints from bundle
    echo "--- API endpoints in bundle ---"
    grep -oP '"/(api|auth|socket|ws)[^"]*"' 9ns1_bundle.js 2>/dev/null | sort -u | head -20
    
    # Extract URLs
    echo "--- URLs in bundle ---"
    grep -oP 'https?://[a-zA-Z0-9._/-]+' 9ns1_bundle.js 2>/dev/null | sort -u | head -30
    
    # Extract event names (Socket.IO)
    echo "--- Socket.IO events in bundle ---"
    grep -oP '"(emit|on)\("[^"]*"' 9ns1_bundle.js 2>/dev/null | sort -u | head -30
    grep -oP '"[a-z]+:[a-zA-Z]+"' 9ns1_bundle.js 2>/dev/null | sort -u | head -30
    
    # Look for auth/token patterns
    echo "--- Auth patterns ---"
    grep -oP '"(token|apiKey|api_key|authorization|bearer|jwt|session)[^"]*"' 9ns1_bundle.js 2>/dev/null | sort -u | head -10
    
    # Discord webhook URLs
    echo "--- Discord webhooks in bundle ---"
    grep -oP 'https://discord\.com/api/webhooks/[0-9]+/[a-zA-Z0-9_-]+' 9ns1_bundle.js 2>/dev/null | sort -u
fi

echo ""
echo "=========================================="
echo "5. PANEL API PROBING"
echo "=========================================="

for path in api api/v1 api/servers api/users api/auth api/login api/register \
            api/health api/status api/config api/webhook api/webhooks \
            api/me api/server api/resource api/resources api/player api/players \
            socket.io "socket.io/?EIO=4&transport=polling" \
            login register dashboard admin \
            .env config.json package.json robots.txt sitemap.xml \
            favicon.ico manifest.json; do
    result=$(curl -s -o /tmp/probe_body -w "%{http_code}:%{size_download}" "https://9ns1.com/$path" -H "User-Agent: Mozilla/5.0" --connect-timeout 3 2>/dev/null)
    code=$(echo $result | cut -d: -f1)
    size=$(echo $result | cut -d: -f2)
    if [ "$code" != "000" ] && [ "$code" != "404" ]; then
        preview=$(head -c 200 /tmp/probe_body 2>/dev/null | tr '\n\r' '  ')
        echo "/$path → HTTP $code ($size bytes)"
        if [ -n "$preview" ] && [ ${#preview} -gt 5 ]; then
            echo "  ${preview:0:150}"
        fi
    fi
done

echo ""
echo "=========================================="
echo "6. INFRASTRUCTURE DEEP DIVE"
echo "=========================================="

echo "--- fivems.lt DNS ---"
dig fivems.lt A +short
dig fivems.lt AAAA +short 2>/dev/null
dig fivems.lt MX +short 2>/dev/null
dig fivems.lt TXT +short 2>/dev/null
dig fivems.lt NS +short 2>/dev/null

echo ""
echo "--- fivems.lt WHOIS ---"
whois fivems.lt 2>/dev/null | grep -iE "registrant|admin|name.server|creation|expir|registrar|status|updated|org|email|phone|country" | head -25

echo ""
echo "--- fivems.lt SSL ---"
echo | openssl s_client -connect fivems.lt:443 -servername fivems.lt 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null

echo ""
echo "--- blum-panel.me ---"
dig blum-panel.me A +short
dig blum-panel.me AAAA +short 2>/dev/null
dig blum-panel.me NS +short 2>/dev/null
curl -s -o /dev/null -w "HTTP %{http_code}, %{size_download} bytes\n" "https://blum-panel.me/" --connect-timeout 5 2>/dev/null
echo | openssl s_client -connect blum-panel.me:443 -servername blum-panel.me 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null

echo ""
echo "--- 185.80.128.35 (stolen resource host) ---"
dig -x 185.80.128.35 +short 2>/dev/null
whois 185.80.128.35 2>/dev/null | grep -iE "netname|org-name|descr|country|address|person|admin|abuse|route|origin" | head -20

# Try common paths on the file host
for fpath in / /download-resource /download-resource/1 /download-resource/test /api /status; do
    result=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "http://185.80.128.35${fpath}" -H "User-Agent: node" --connect-timeout 3 2>/dev/null)
    code=$(echo $result | cut -d: -f1)
    size=$(echo $result | cut -d: -f2)
    echo "185.80.128.35${fpath} → HTTP $code ($size bytes)"
done

echo ""
echo "=========================================="
echo "7. SOCKET.IO HANDSHAKE ATTEMPTS"
echo "=========================================="

for host in fivems.lt 9ns1.com; do
    echo "--- $host ---"
    # Standard Socket.IO polling handshake
    curl -s "https://$host/socket.io/?EIO=4&transport=polling" \
        -H "User-Agent: node" --connect-timeout 5 2>/dev/null | head -c 500
    echo ""
    
    # Try with different paths
    curl -s "https://$host/ws" -H "Upgrade: websocket" -H "Connection: Upgrade" \
        --connect-timeout 5 -w "HTTP: %{http_code}\n" 2>/dev/null | head -c 200
    echo ""
done

echo ""
echo "=========================================="
echo "8. PAYLOAD COMPARISON & FINGERPRINTING"
echo "=========================================="

echo "--- File sizes and hashes ---"
for f in ~/blum-probe/*.txt ~/blum-probe/*.js ~/blum-probe/*.html 2>/dev/null; do
    [ -f "$f" ] || continue
    size=$(wc -c < "$f")
    [ "$size" -lt 10 ] && continue
    md5=$(md5sum "$f" | cut -d' ' -f1)
    fname=$(basename "$f")
    echo "$fname: $size bytes, MD5: $md5"
done

echo ""
echo "--- Payload config extraction ---"
for f in ~/blum-probe/9ns1_*.txt; do
    [ -f "$f" ] || continue
    size=$(wc -c < "$f")
    [ "$size" -lt 100 ] && continue
    fname=$(basename "$f")
    echo "=== $fname ==="
    # Extract ende (apiKey) and back (C2 URL) 
    grep -oP 'ende\s*=\s*"[^"]*"' "$f" 2>/dev/null | head -1
    grep -oP 'back\s*=\s*"[^"]*"' "$f" 2>/dev/null | head -1
    # Extract setInterval value (poll interval)
    grep -oP 'setInterval\s*=\s*"[^"]*"' "$f" 2>/dev/null | head -1
    # Check if it's the same Function wrapper
    head -c 30 "$f" | cat -v
    echo ""
    echo ""
done

echo ""
echo "=========================================="
echo "9. CERT TRANSPARENCY LOG SEARCH"
echo "=========================================="

# Search crt.sh for all certs issued to these domains
echo "--- 9ns1.com certificates ---"
curl -s "https://crt.sh/?q=9ns1.com&output=json" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    seen = set()
    for cert in sorted(data, key=lambda x: x.get('id', 0)):
        cn = cert.get('common_name', '')
        na = cert.get('name_value', '')
        nb = cert.get('not_before', '')
        if cn not in seen:
            seen.add(cn)
            print(f'  CN={cn}  SAN={na}  NotBefore={nb}')
except: pass
" 2>/dev/null

echo ""
echo "--- fivems.lt certificates ---"
curl -s "https://crt.sh/?q=fivems.lt&output=json" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    seen = set()
    for cert in sorted(data, key=lambda x: x.get('id', 0)):
        cn = cert.get('common_name', '')
        na = cert.get('name_value', '')
        nb = cert.get('not_before', '')
        if cn not in seen:
            seen.add(cn)
            print(f'  CN={cn}  SAN={na}  NotBefore={nb}')
except: pass
" 2>/dev/null

echo ""
echo "--- blum-panel.me certificates ---"
curl -s "https://crt.sh/?q=blum-panel.me&output=json" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    seen = set()
    for cert in sorted(data, key=lambda x: x.get('id', 0)):
        cn = cert.get('common_name', '')
        na = cert.get('name_value', '')
        nb = cert.get('not_before', '')
        if cn not in seen:
            seen.add(cn)
            print(f'  CN={cn}  SAN={na}  NotBefore={nb}')
except: pass
" 2>/dev/null

echo ""
echo "=========================================="
echo "10. DISCORD SERVER INTEL"
echo "=========================================="

# Check the Discord invite from the malware comments
echo "--- discord.com/invite/VB8mdVjrzd ---"
curl -s "https://discord.com/api/v10/invites/VB8mdVjrzd?with_counts=true&with_expiration=true" | python3 -m json.tool 2>/dev/null

# Check the Discord app
echo ""
echo "--- Discord App 1444110004402655403 ---"
curl -s "https://discord.com/api/v10/applications/1444110004402655403/rpc" | python3 -m json.tool 2>/dev/null

echo ""
echo "=========================================="
echo "11. THIRD DOMAIN: blum-panel.com"
echo "=========================================="

# blum-panel.com discovered via Discord bot listing - has /en/agreement page
echo "--- blum-panel.com DNS ---"
dig blum-panel.com A +short
dig blum-panel.com AAAA +short 2>/dev/null
dig blum-panel.com NS +short 2>/dev/null

echo "--- blum-panel.com SSL ---"
echo | openssl s_client -connect blum-panel.com:443 -servername blum-panel.com 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>/dev/null

echo "--- blum-panel.com pages ---"
curl -s -o /dev/null -w "/ → HTTP %{http_code}, %{size_download} bytes\n" "https://blum-panel.com/" --connect-timeout 5
curl -s -o /dev/null -w "/en/agreement → HTTP %{http_code}, %{size_download} bytes\n" "https://blum-panel.com/en/agreement" --connect-timeout 5
curl -s -o /dev/null -w "/discord → HTTP %{http_code}, %{size_download} bytes\n" "https://blum-panel.com/discord" --connect-timeout 5

echo "--- blum-panel.com WHOIS ---"
whois blum-panel.com 2>/dev/null | grep -iE "registrant|admin|name.server|creation|expir|registrar|email|country" | head -15

# Cert transparency for all 3 panel domains  
echo ""
echo "--- CT Logs: blum-panel.com ---"
curl -s "https://crt.sh/?q=blum-panel.com&output=json" 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for cert in sorted(data, key=lambda x: x.get('id', 0)):
        cn = cert.get('common_name', '')
        na = cert.get('name_value', '')
        nb = cert.get('not_before', '')
        print(f'  CN={cn}  SAN={na}  NotBefore={nb}')
except: pass
" 2>/dev/null

echo ""
echo "=========================================="
echo "12. VIMEO CHANNEL INTEL"
echo "=========================================="
# They have a Vimeo channel with tutorial videos
curl -s "https://vimeo.com/channels/1864287" -o /dev/null -w "Vimeo channel: HTTP %{http_code}\n"

echo ""
echo "=========================================="
echo "13. IP CORRELATION CHECK"  
echo "=========================================="
# Check if blum-panel.me, blum-panel.com, 9ns1.com share Cloudflare IPs
echo "9ns1.com:"
dig 9ns1.com +short
echo "blum-panel.me:"
dig blum-panel.me +short  
echo "blum-panel.com:"
dig blum-panel.com +short
echo "fivems.lt:"
dig fivems.lt +short

echo ""
echo "=========================================="
echo "PROBE COMPLETE"
echo "=========================================="
echo "Files saved in ~/blum-probe/"
ls -la ~/blum-probe/*.txt ~/blum-probe/*.js ~/blum-probe/*.html 2>/dev/null
echo ""
echo "Upload interesting findings:"
echo "  - 9ns1_test.txt and 9ns1_dev.txt (unknown payloads)"
echo "  - 9ns1_bundle.js (panel frontend code)"  
echo "  - probe_results.txt (this output)"
