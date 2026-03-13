#!/bin/bash
# ============================================================================
# BLUM PANEL MALWARE SCANNER v3
# ============================================================================
# Scans a FiveM server for all known Blum Panel / bertjj / miauss artifacts.
# Run from the server root directory.
# ============================================================================

RED='\033[0;31m'
YEL='\033[1;33m'
GRN='\033[0;32m'
CYN='\033[0;36m'
NC='\033[0m'

echo ""
echo "============================================"
echo "  BLUM PANEL MALWARE SCANNER v3"
echo "============================================"
echo ""

FOUND=0
SCAN_DIR="${1:-.}"

# ---------- 1. XOR DROPPER PATTERN ----------
echo -e "${CYN}[1/8] Scanning for XOR dropper pattern...${NC}"
hits=$(grep -rn "String.fromCharCode(a\[i\]\^k)" --include="*.js" "$SCAN_DIR" 2>/dev/null)
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — XOR dropper files:${NC}"
    echo "$hits" | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 2. ATTACKER STRINGS ----------
echo -e "${CYN}[2/8] Scanning for attacker identifiers...${NC}"
hits=$(grep -rn "bertjj\|bertJJ\|miauss\|miausas\|fivems\.lt\|VB8mdVjrzd\|blum-panel\|warden-panel\|ggWP" --include="*.js" --include="*.lua" --include="*.cfg" "$SCAN_DIR" 2>/dev/null | grep -v "dropper_trap\|SCANNER\|scan.sh\|block_c2\|README\|\.md$")
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — Attacker strings:${NC}"
    echo "$hits" | head -20 | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 3. TXADMIN TAMPERING ----------
echo -e "${CYN}[3/8] Scanning for txAdmin tampering...${NC}"
hits=$(grep -rn "RESOURCE_EXCLUDE\|isExcludedResource\|onServerResourceFail\|helpEmptyCode\|JohnsUrUncle\|txadmin:js_create" --include="*.lua" "$SCAN_DIR" 2>/dev/null | grep -v "dropper_trap\|scan.sh\|README")
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — txAdmin backdoor indicators:${NC}"
    echo "$hits" | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 3b. TXADMIN BACKDOOR ADMIN ACCOUNT ----------
echo -e "${CYN}[3b/8] Checking txAdmin for backdoor admin 'JohnsUrUncle'...${NC}"
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
echo -e "${CYN}[3c/8] Checking txAdmin files individually...${NC}"
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
echo -e "${CYN}[4/8] Scanning for dropper files in suspicious paths...${NC}"
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
echo -e "${CYN}[5/8] Checking for C2 domains in code...${NC}"
C2_DOMAINS="fivems\.lt\|0xchitado\.com\|giithub\.net\|fivemgtax\.com\|warden-panel\.me\|bhlool\.com\|flowleakz\.org\|z1lly\.org\|l00x\.org\|monloox\.com\|noanimeisgay\.com\|2ns3\.net\|5mscripts\.net\|2312321321321213\.com"
hits=$(grep -rn "$C2_DOMAINS" --include="*.js" --include="*.lua" "$SCAN_DIR" 2>/dev/null | grep -v "dropper_trap\|scan.sh\|block_c2\|README\|\.md$\|\.txt$")
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — C2 domain references:${NC}"
    echo "$hits" | head -10 | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 6. LZSTRING / OBFUSCATION MARKERS ----------
echo -e "${CYN}[6/8] Scanning for obfuscation markers...${NC}"
hits=$(grep -rn "decompressFromUTF16\|\\\\u15E1\|aga\[0x\|UARZT6\[" --include="*.js" "$SCAN_DIR" 2>/dev/null | grep -v "dropper_trap\|scan.sh\|README\|deobfuscated")
if [ -n "$hits" ]; then
    echo -e "${RED}  FOUND — Obfuscation markers:${NC}"
    echo "$hits" | head -5 | while read line; do echo -e "  ${RED}$line${NC}"; done
    FOUND=$((FOUND + $(echo "$hits" | wc -l)))
else
    echo -e "  ${GRN}Clean${NC}"
fi

# ---------- 7. FXMANIFEST INJECTION ----------
echo -e "${CYN}[7/8] Checking fxmanifest.lua files for suspicious entries...${NC}"
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
echo -e "${CYN}[8/8] Checking /etc/hosts for C2 blocks...${NC}"
if grep -q "fivems.lt" /etc/hosts 2>/dev/null; then
    echo -e "  ${GRN}fivems.lt is blocked in /etc/hosts${NC}"
else
    echo -e "  ${YEL}WARNING: fivems.lt is NOT blocked in /etc/hosts${NC}"
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
