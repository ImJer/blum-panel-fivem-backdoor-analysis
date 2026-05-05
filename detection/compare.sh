#!/bin/bash
# ============================================================================
# BLUM PANEL BASELINE COMPARISON
# ============================================================================
# Compares the current state of a FiveM server-data directory against a
# previously-captured baseline (created by baseline.sh). Reports modified,
# added, and removed files.
#
# Usage:
#   detection/compare.sh /path/to/server-data baseline-20260505.json
#
# Exit codes:
#   0  No drift detected
#   1  Drift detected (files modified, added, or removed)
#   3  Argument error (missing baseline file, etc.)
#
# Requires python3.
# ============================================================================

set -e

SCAN_DIR="${1:-.}"
BASELINE="$2"

if [ -z "$BASELINE" ] || [ ! -f "$BASELINE" ]; then
    echo "Usage: $0 <scan_dir> <baseline.json>" >&2
    echo "  Run baseline.sh first to create the baseline file." >&2
    exit 3
fi

if [ ! -d "$SCAN_DIR" ]; then
    echo "ERROR: $SCAN_DIR is not a directory" >&2
    exit 3
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required (apt install python3 / yum install python3)" >&2
    exit 3
fi

SCAN_DIR_ABS="$(cd "$SCAN_DIR" && pwd)"
BASELINE_ABS="$(cd "$(dirname "$BASELINE")" && pwd)/$(basename "$BASELINE")"

python3 - "$SCAN_DIR_ABS" "$BASELINE_ABS" <<'PYEOF'
import sys, os, hashlib, json

RED = '\033[0;31m'
YEL = '\033[1;33m'
GRN = '\033[0;32m'
CYN = '\033[0;36m'
NC  = '\033[0m'

scan_dir = sys.argv[1]
baseline_file = sys.argv[2]

with open(baseline_file) as f:
    baseline = json.load(f)

baseline_map = {e['path']: e for e in baseline['files']}

current_map = {}
for root, dirs, fnames in os.walk(scan_dir):
    dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules', '__pycache__')]
    for fname in fnames:
        if not (fname.endswith('.lua') or fname.endswith('.js')):
            continue
        full = os.path.join(root, fname)
        try:
            with open(full, 'rb') as f:
                content = f.read()
            rel = os.path.relpath(full, scan_dir).replace(os.sep, '/')
            current_map[rel] = {
                'path': rel,
                'size': len(content),
                'sha256': hashlib.sha256(content).hexdigest(),
            }
        except Exception:
            pass

modified = []
added = []
removed = []

for k, cur in current_map.items():
    if k not in baseline_map:
        added.append(cur)
    elif baseline_map[k]['sha256'] != cur['sha256']:
        modified.append({
            'path': k,
            'old_sha256': baseline_map[k]['sha256'],
            'new_sha256': cur['sha256'],
            'old_size': baseline_map[k].get('size', 0),
            'new_size': cur['size'],
        })

for k, base in baseline_map.items():
    if k not in current_map:
        removed.append(base)

print()
print('============================================')
print(' BLUM PANEL BASELINE COMPARISON')
print('============================================')
print(f' Scan path:      {scan_dir}')
print(f' Baseline file:  {baseline_file}')
print(f' Files now:      {len(current_map)}')
print(f' Files baseline: {len(baseline_map)}')
print(f'')
print(f' Modified: {len(modified)}')
print(f' Added:    {len(added)}')
print(f' Removed:  {len(removed)}')
print()

if modified:
    print(f'{RED}=== MODIFIED FILES ==={NC}')
    for m in modified:
        print(f'{RED}  {m["path"]}{NC}')
        print(f'    old: {m["old_sha256"][:16]}... ({m["old_size"]} bytes)')
        print(f'    new: {m["new_sha256"][:16]}... ({m["new_size"]} bytes)')
    print()

if added:
    print(f'{YEL}=== ADDED FILES ==={NC}')
    for a in added:
        print(f'{YEL}  {a["path"]} ({a["size"]} bytes, sha256 {a["sha256"][:16]}...){NC}')
    print()

if removed:
    print(f'{CYN}=== REMOVED FILES ==={NC}')
    for r in removed:
        print(f'{CYN}  {r["path"]}{NC}')
    print()

if modified or added or removed:
    print(f'{YEL}DRIFT DETECTED. Review every modified file — confirm changes were intentional.{NC}')
    print(f'{YEL}If any changes are unexpected, treat as possible tampering.{NC}')
    sys.exit(1)
else:
    print(f'{GRN}No drift detected. {len(current_map)} files match the baseline.{NC}')
    sys.exit(0)
PYEOF
