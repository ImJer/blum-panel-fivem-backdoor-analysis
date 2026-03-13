#!/bin/bash
# ============================================================================
# Blum Panel / bertjj Malware Scanner
# ============================================================================
# Scans a FiveM server's resources directory for all known variants.
# Run as: ./scan.sh /path/to/resources/
# ============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./scan.sh /path/to/resources/"
    echo "Example: ./scan.sh /home/container/resources/"
    exit 1
fi

RESOURCE_PATH="$1"
TOTAL=0

echo "============================================"
echo " Blum Panel Malware Scanner"
echo " Scanning: $RESOURCE_PATH"
echo "============================================"
echo ""

# Check 1: XOR backdoor files
echo "[1/5] Scanning for XOR backdoor files..."
while IFS= read -r file; do
    if grep -q "eval(d.*,k.*)" "$file"; then
        CREATED=$(stat -c "%w" "$file" 2>/dev/null || echo "unknown")
        MODIFIED=$(stat -c "%y" "$file" 2>/dev/null || echo "unknown")
        SIZE=$(wc -c < "$file")
        KEYS=$(grep -oP 'const k\w+=\K\d+' "$file" | tr '\n' ',' | sed 's/,$//')
        BLOCKS=$(grep -c 'String.fromCharCode' "$file")
        echo "  ████ 100% MALWARE: $file"
        echo "      Size: $SIZE bytes | XOR keys: $KEYS | Blocks: $BLOCKS"
        echo "      Created:  $CREATED"
        echo "      Modified: $MODIFIED"
        TOTAL=$((TOTAL + 1))
    fi
done < <(find "$RESOURCE_PATH" -name "*.js" -not -path "*/node_modules/*" -not -path "*/dropper_trap/*" \
  -exec grep -l "String.fromCharCode(a\[i\]\^k)" {} \; 2>/dev/null)
echo ""

# Check 2: Heavy obfuscation (Blum Panel core)
echo "[2/5] Scanning for Blum Panel core files..."
for pattern in 'Function("a",' 'Function("tqVTPU",'; do
    while IFS= read -r file; do
        echo "  ████ BLUM PANEL CORE: $file ($(wc -c < "$file") bytes)"
        TOTAL=$((TOTAL + 1))
    done < <(grep -rl "$pattern" "$RESOURCE_PATH" --include="*.js" 2>/dev/null)
done
echo ""

# Check 3: Tampered txAdmin files
echo "[3/5] Scanning for tampered system files..."
while IFS= read -r file; do
    echo "  ████ TAMPERED (resource hiding): $file"
    TOTAL=$((TOTAL + 1))
done < <(grep -rl "RESOURCE_EXCLUDE\|isExcludedResource" "$RESOURCE_PATH" --include="*.lua" 2>/dev/null)

while IFS= read -r file; do
    echo "  ████ TAMPERED (RCE backdoor): $file"
    TOTAL=$((TOTAL + 1))
done < <(grep -rl "onServerResourceFail" "$RESOURCE_PATH" --include="*.lua" 2>/dev/null | grep -v "dropper_trap")
echo ""

# Check 4: Attacker fingerprints
echo "[4/5] Scanning for attacker fingerprints..."
while IFS= read -r file; do
    MATCHES=$(grep -oP "bertjj|bertJJ|miauss|miausas|fivems\.lt|VB8mdVjrzd" "$file" | sort -u | tr '\n' ', ' | sed 's/,$//')
    echo "  ████ FINGERPRINT: $file"
    echo "      Matches: $MATCHES"
    TOTAL=$((TOTAL + 1))
done < <(grep -rl "bertjj\|bertJJ\|miauss\|miausas\|fivems\.lt\|VB8mdVjrzd" "$RESOURCE_PATH" 2>/dev/null | grep -v "dropper_trap" | grep -v "node_modules")
echo ""

# Check 5: Suspicious fxmanifest entries
echo "[5/5] Scanning for suspicious fxmanifest entries..."
echo "  (Map/vehicle resources should NOT have .js server scripts)"
while IFS= read -r manifest; do
    if grep -q "server_script\|shared_script" "$manifest" 2>/dev/null; then
        JS_SCRIPTS=$(grep -P "server_script|shared_script" "$manifest" | grep -oP "'[^']*\.js'" | tr '\n' ', ' | sed 's/,$//')
        if [ ! -z "$JS_SCRIPTS" ]; then
            echo "  ⚠ SUSPICIOUS: $manifest"
            echo "      Map resource loading JS: $JS_SCRIPTS"
        fi
    fi
done < <(find "$RESOURCE_PATH" -name "fxmanifest.lua" -exec grep -l 'this_is_a_map' {} \; 2>/dev/null)
echo ""

# Check infected yarn/webpack
echo "[BONUS] Checking system builder files..."
for builder in "yarn/yarn_builder.js" "webpack/webpack_builder.js"; do
    FOUND=$(find "$RESOURCE_PATH" -path "*$builder" 2>/dev/null)
    if [ ! -z "$FOUND" ]; then
        SIZE=$(wc -c < "$FOUND")
        if [ "$SIZE" -gt 10000 ]; then
            echo "  ████ INFECTED: $FOUND ($SIZE bytes — should be ~6KB)"
            TOTAL=$((TOTAL + 1))
        else
            echo "  ✓ CLEAN: $FOUND ($SIZE bytes)"
        fi
    fi
done
echo ""

echo "============================================"
echo " RESULTS: $TOTAL infected files found"
echo "============================================"
if [ "$TOTAL" -gt 0 ]; then
    echo ""
    echo " Your server is infected with the Blum Panel backdoor."
    echo " See README.md for remediation steps."
else
    echo ""
    echo " No infections detected. Your server appears clean."
    echo " Consider running this scan weekly and after"
    echo " installing any new resources."
fi
echo ""
