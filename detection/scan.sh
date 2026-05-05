#!/bin/bash
# ============================================================================
# BLUM PANEL MALWARE SCANNER v4
# ============================================================================
# Scans a FiveM server for all known Blum Panel / bertjj / miauss artifacts.
# Run from the server root directory.
# Changes from v3:
#   - Fixed check numbering (1-13 sequential)
#   - Added 9ns1.com, cipher-panel.me, blum-panel.com to C2 domain checks
#   - Added Cipher Panel domains to detection
# ============================================================================

RED='\033[0;31m'
YEL='\033[1;33m'
GRN='\033[0;32m'
CYN='\033[0;36m'
NC='\033[0m'

echo ""
echo "============================================"
echo "  BLUM PANEL MALWARE SCANNER v4"
echo "============================================"
echo ""

FOUND=0
SCAN_DIR="${1:-.}"

# ---------- 1. XOR DROPPER PATTERN ----------
echo -e "${CYN}[1/13] Scanning for XOR dropper pattern...${NC}"
hits=$(grep -rn "String.fromCharCode(a\[i\]\^k)" --include="*.js" "$SCAN_DIR" 2>/dev/null)
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — XOR dropper files:${NC}"
    echo "$hits" | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 2. ATTACKER STRINGS ----------
# Alternation of attacker handles, panel brand names, and operator constants.
# The \| separators are grep BRE alternation ("or"), not parts of one name.
# Any single match in .js/.lua/.cfg is a high-confidence indicator.
echo -e "${CYN}[2/13] Scanning for attacker identifiers...${NC}"
hits=$(grep -rn "bertjj\|bertJJ\|miauss\|miausas\|fivems\.lt\|9ns1\.com\|VB8mdVjrzd\|blum-panel\|warden-panel\|cipher-panel\|gfxpanel\|ggWP" --include="*.js" --include="*.lua" --include="*.cfg" "$SCAN_DIR" 2>/dev/null | grep -v "dropper_trap\|SCANNER\|scan.sh\|block_c2\|README\|\.md$")
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — Attacker strings:${NC}"
    echo "$hits" | head -20 | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 3. TXADMIN TAMPERING ----------
# Single grep matching ANY of 6 markers (\| is regex alternation — "or" — NOT
# part of an event name). Each marker is a SEPARATE injection point in a
# SEPARATE file:
#   helpEmptyCode          -> client-side RCE in monitor/resource/cl_playerlist.lua
#   RESOURCE_EXCLUDE       -> resource cloaking list in monitor/resource/sv_main.lua
#   isExcludedResource     -> resource cloaking helper in monitor/resource/sv_main.lua
#   onServerResourceFail   -> server-side RCE in monitor/resource/sv_resources.lua
#   JohnsUrUncle           -> backdoor admin account name in txData/admins.json
#   txadmin:js_create      -> JS execution event used by some Blum variants
# A clean txAdmin install does not contain any of these. See
# docs/TXADMIN_TAMPERING.md for what each injection looks like and the
# recommended remediation (full reinstall, not surgery).
echo -e "${CYN}[3/13] Scanning for txAdmin tampering...${NC}"
hits=$(grep -rn "RESOURCE_EXCLUDE\|isExcludedResource\|onServerResourceFail\|helpEmptyCode\|JohnsUrUncle\|txadmin:js_create" --include="*.lua" "$SCAN_DIR" 2>/dev/null | grep -v "dropper_trap\|scan.sh\|README")
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — txAdmin backdoor indicators:${NC}"
    echo "$hits" | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 3b. TXADMIN BACKDOOR ADMIN ACCOUNT ----------
echo -e "${CYN}[4/13] Checking txAdmin for backdoor admin 'JohnsUrUncle'...${NC}"
admin_found=0
find "$SCAN_DIR" -name "admins.json" -o -name "*.json" -path "*txData*" -o -name "*.json" -path "*txAdmin*" 2>/dev/null | while read f; do
    if grep -qi "JohnsUrUncle\|johnsuruncle" "$f" 2>/dev/null; then
        echo -e "${RED}  FOUND — Backdoor admin in: $f${NC}"
        echo -e "${RED}  DELETE THIS ACCOUNT IMMEDIATELY and rotate all txAdmin passwords${NC}"
        admin_found=1
    fi
done
if [ "$admin_found" -eq 0 ]; then echo -e "  ${GRN}Clean${NC}"; fi

# ---------- 3c. TXADMIN FILES — INDIVIDUAL CHECK ----------
echo -e "${CYN}[5/13] Checking txAdmin files individually...${NC}"
find "$SCAN_DIR" -name "cl_playerlist.lua" -path "*/monitor/*" 2>/dev/null | while read f; do
    if grep -q "helpEmptyCode" "$f" 2>/dev/null; then
        echo -e "${RED}  INFECTED: $f — client RCE backdoor (helpEmptyCode)${NC}"
        echo -e "${RED}  FIX: curl -o \"$f\" https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/cl_playerlist.lua${NC}"
        FOUND=$((FOUND + 1))
    else
        echo -e "  ${GRN}cl_playerlist.lua: Clean${NC}"
    fi
done
find "$SCAN_DIR" -name "sv_main.lua" -path "*/monitor/*" 2>/dev/null | while read f; do
    if grep -q "RESOURCE_EXCLUDE\|isExcludedResource" "$f" 2>/dev/null; then
        echo -e "${RED}  INFECTED: $f — dashboard resource cloaking${NC}"
        echo -e "${RED}  FIX: curl -o \"$f\" https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/sv_main.lua${NC}"
        FOUND=$((FOUND + 1))
    else
        echo -e "  ${GRN}sv_main.lua: Clean${NC}"
    fi
done
find "$SCAN_DIR" -name "sv_resources.lua" -path "*/monitor/*" 2>/dev/null | while read f; do
    if grep -q "onServerResourceFail" "$f" 2>/dev/null; then
        echo -e "${RED}  INFECTED: $f — server RCE backdoor${NC}"
        echo -e "${RED}  FIX: curl -o \"$f\" https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/sv_resources.lua${NC}"
        FOUND=$((FOUND + 1))
    else
        echo -e "  ${GRN}sv_resources.lua: Clean${NC}"
    fi
done

# ---------- 4. KNOWN DROPPER FILENAMES IN SUSPICIOUS LOCATIONS ----------
echo -e "${CYN}[6/13] Scanning for dropper files in suspicious paths...${NC}"
for name in babel_config.js jest_mock.js mock_data.js webpack_bundle.js env_backup.js cache_old.js build_cache.js vite_temp.js eslint_rc.js jest_setup.js test_utils.js utils_lib.js helper_functions.js sync_worker.js queue_handler.js session_store.js hook_system.js patch_update.js; do
    finds=$(find "$SCAN_DIR" -name "$name" -path "*/server/*" -o -name "$name" -path "*/modules/*" -o -name "$name" -path "*/node_modules/.cache/*" -o -name "$name" -path "*/middleware/*" -o -name "$name" -path "*/dist/*" 2>/dev/null)
    if [ -n "$finds" ]; then
        echo "$finds" | while read f; do
            if grep -q "fromCharCode\|eval(" "$f" 2>/dev/null; then
                echo -e "  ${RED}INFECTED: $f${NC}"
                FOUND=$((FOUND + 1))
            else
                echo -e "  ${YEL}SUSPICIOUS: $f (check manually)${NC}"
            fi
        done
    fi
done
echo -e "  ${GRN}Done${NC}"

# ---------- 5. C2 DOMAIN CONNECTIONS ----------
echo -e "${CYN}[7/13] Checking for C2 domains in code...${NC}"
C2_DOMAINS="9ns1\.com\|fivems\.lt\|0xchitado\.com\|giithub\.net\|fivemgtax\.com\|warden-panel\.me\|bhlool\.com\|flowleakz\.org\|z1lly\.org\|l00x\.org\|monloox\.com\|noanimeisgay\.com\|2ns3\.net\|5mscripts\.net\|2312321321321213\.com\|cipher-panel\.me\|ciphercheats\.com\|blum-panel\.com\|blum-panel\.me"
hits=$(grep -rn "$C2_DOMAINS" --include="*.js" --include="*.lua" "$SCAN_DIR" 2>/dev/null | grep -v "dropper_trap\|scan.sh\|block_c2\|README\|\.md$\|\.txt$")
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — C2 domain references:${NC}"
    echo "$hits" | head -10 | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 6. LZSTRING / OBFUSCATION MARKERS ----------
# Alternation of obfuscation residue (\| = "or"):
#   decompressFromUTF16 -> lz-string runtime call used to inflate payloads
#   \\u15E1             -> JScrambler array-key Unicode escape
#   aga[0x              -> runtime array indexing pattern in c2_payload.js
#   UARZT6[             -> JScrambler indirection-array reference
echo -e "${CYN}[8/13] Scanning for obfuscation markers...${NC}"
hits=$(grep -rn "decompressFromUTF16\|\\\\u15E1\|aga\[0x\|UARZT6\[" --include="*.js" "$SCAN_DIR" 2>/dev/null | grep -v "dropper_trap\|scan.sh\|README\|deobfuscated")
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — Obfuscation markers:${NC}"
    echo "$hits" | head -5 | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 7. FXMANIFEST INJECTION ----------
echo -e "${CYN}[9/13] Checking fxmanifest.lua files for suspicious entries...${NC}"
find "$SCAN_DIR" -name "fxmanifest.lua" 2>/dev/null | while read manifest; do
    suspicious=$(grep -n "node_modules/\.\|\.cache/\|middleware/\|dist/.*\.js\|babel_config\|jest_mock\|mock_data\|webpack_bundle\|env_backup\|cache_old\|build_cache\|vite_temp" "$manifest" 2>/dev/null)
    if [ -n "$suspicious" ]; then
        echo -e "  ${RED}SUSPICIOUS ENTRY in $manifest:${NC}"
        echo "$suspicious" | while read line; do echo -e "    ${RED}$line${NC}"; done
        FOUND=$((FOUND + 1))
    fi
done
echo -e "  ${GRN}Done${NC}"

# ---------- 8. SERVER.CFG CHECK ----------
echo -e "${CYN}[10/13] Checking /etc/hosts for C2 blocks (fivems.lt + 9ns1.com)...${NC}"
if grep -q "fivems.lt" /etc/hosts 2>/dev/null; then
    echo -e "  ${GRN}fivems.lt is blocked in /etc/hosts${NC}"
else
    echo -e "  ${YEL}WARNING: fivems.lt is NOT blocked in /etc/hosts${NC}"
fi

# --- CHECK 11: Luraph Lua payloads ---
echo -e "${CYN}[11/13] Checking for Luraph Lua dropper signatures...${NC}"
LURAPH=$(grep -rn "Luraph Obfuscator" --include="*.lua" 2>/dev/null | head -5)
if [ -n "$LURAPH" ]; then
    echo -e "  ${RED}FOUND: Luraph obfuscated Lua files:${NC}"
    echo "$LURAPH" | while read line; do echo -e "    ${RED}$line${NC}"; done
    FOUND=$((FOUND+1))
fi

# --- CHECK 12: Luraph dropper JS filenames + KVP persistence ---
# Alternation of Luraph-family dropper artefacts (\| = "or"):
#   installed_notices       -> KVP persistence key written by the dropper
#   vm').runInThisContext   -> Node VM module string used to evaluate payloads
#   9ns1.com                -> primary C2 host
#   devJJ / nullJJ / zXeAHJJ -> operator JJ-suffix API keys
echo -e "${CYN}[12/13] Checking for Luraph dropper artifacts...${NC}"
DROPPER_JS=$(grep -rn "installed_notices\|vm').runInThisContext\|9ns1\.com\|devJJ\|nullJJ\|zXeAHJJ" --include="*.js" --include="*.lua" 2>/dev/null | head -5)
if [ -n "$DROPPER_JS" ]; then
    echo -e "  ${RED}FOUND: Luraph dropper artifacts:${NC}"
    echo "$DROPPER_JS" | while read line; do echo -e "    ${RED}$line${NC}"; done
    FOUND=$((FOUND+1))
fi

# --- CHECK 13: Discord webhook phone-home ---
echo -e "${CYN}[13/13] Checking for Discord webhook IOC...${NC}"
WEBHOOK=$(grep -rn "1470175544682217685\|pe8DNcnZCjKPlKF24tk72R" --include="*.lua" --include="*.js" 2>/dev/null | head -5)
if [ -n "$WEBHOOK" ]; then
    echo -e "  ${RED}FOUND: Blum Panel Discord webhook:${NC}"
    echo "$WEBHOOK" | while read line; do echo -e "    ${RED}$line${NC}"; done
    FOUND=$((FOUND+1))
fi

# --- CHECK: 9ns1.com blocked ---
if grep -q "9ns1.com" /etc/hosts 2>/dev/null; then
    echo -e "  ${GRN}OK: 9ns1.com is blocked in /etc/hosts${NC}"
else
    echo -e "  ${YEL}WARNING: 9ns1.com is NOT blocked in /etc/hosts${NC}"
fi

echo ""
echo "============================================"
if [ $FOUND -gt 0 ]; then
    echo -e "  ${RED}SCAN COMPLETE: $FOUND indicator(s) found${NC}"
    echo -e "  ${RED}Server may be infected with Blum Panel${NC}"
else
    echo -e "  ${GRN}SCAN COMPLETE: No indicators found${NC}"
    echo -e "  ${GRN}Server appears clean${NC}"
fi
echo "============================================"
echo ""
