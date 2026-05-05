#!/bin/bash
# ============================================================================
# BLUM PANEL RESOURCE BASELINE
# ============================================================================
# Walks a FiveM server-data directory, computes SHA256 of every .lua and .js,
# and emits a structured JSON manifest to stdout. Pair with compare.sh to
# detect drift on subsequent runs.
#
# Usage:
#   detection/baseline.sh /path/to/server-data > baseline-$(date +%Y%m%d).json
#
# Requires python3 (for path-safe JSON encoding).
# ============================================================================

set -e

SCAN_DIR="${1:-.}"

if [ ! -d "$SCAN_DIR" ]; then
    echo "ERROR: $SCAN_DIR is not a directory" >&2
    exit 3
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "ERROR: python3 is required for JSON encoding (apt install python3 / yum install python3)" >&2
    exit 3
fi

SCAN_DIR_ABS="$(cd "$SCAN_DIR" && pwd)"

python3 - "$SCAN_DIR_ABS" <<'PYEOF'
import sys, os, hashlib, json
from datetime import datetime, timezone

scan_dir = sys.argv[1]
files = []

for root, dirs, fnames in os.walk(scan_dir):
    # Skip .git, __pycache__, and any directory the operator marked off-limits
    dirs[:] = [d for d in dirs if d not in ('.git', 'node_modules', '__pycache__')]
    for fname in fnames:
        if not (fname.endswith('.lua') or fname.endswith('.js')):
            continue
        full = os.path.join(root, fname)
        try:
            with open(full, 'rb') as f:
                content = f.read()
            files.append({
                'path': os.path.relpath(full, scan_dir).replace(os.sep, '/'),
                'size': len(content),
                'sha256': hashlib.sha256(content).hexdigest(),
            })
        except Exception:
            # Skip unreadable files silently; baseline tooling shouldn't fail
            # the run for one bad file
            pass

baseline = {
    'tool': 'blum-panel-baseline',
    'version': '1',
    'generated_utc': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'scan_root': scan_dir,
    'file_count': len(files),
    'files': sorted(files, key=lambda x: x['path']),
}

print(json.dumps(baseline, indent=2))
print(f"# Wrote {len(files)} entries (this comment is stripped if you redirect stdout to a file).", file=sys.stderr)
PYEOF
