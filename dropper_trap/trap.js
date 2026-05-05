// ============================================================================
// DROPPER TRAP v4 — JavaScript Hooks (BEHAVIORAL + OPTIMIZED)
// ============================================================================
// Changes from v3:
//   - BEHAVIORAL: any fs.write* / fs.append* targeting monitor/resource/
//     (cl_playerlist|sv_main|sv_resources).lua from a non-monitor resource
//     is blocked regardless of content. Catches txAdmin tampering even when
//     the family rotates marker strings.
//   - REPORTING: optional one-line console banner at startup with the issue
//     submission URL. No automatic reporting; copy-paste only.
//
// IOC SOURCE OF TRUTH: iocs/blum_iocs.json in this repo. The lists below are
// a runtime mirror; when updating, edit the JSON first and mirror here.
// ============================================================================

const fs = require('fs');
const path = require('path');

const orig = {
    writeFile: fs.writeFile,
    writeFileSync: fs.writeFileSync,
    appendFile: fs.appendFile,
    appendFileSync: fs.appendFileSync,
    readFile: fs.readFile,  // keep clean ref for our own scans
};

const origSRF = typeof SaveResourceFile === 'function' ? SaveResourceFile : null;

const SUSPICIOUS = [
    'String.fromCharCode', 'fromCharCode', 'bertjj', 'bertJJ',
    'miauss', 'miausas', 'fivems.lt', '9ns1.com',
    'blum-panel', 'warden-panel', 'cipher-panel', 'gfxpanel',
    'RESOURCE_EXCLUDE', 'isExcludedResource', 'onServerResourceFail',
    'decompressFromUTF16', '\u15E1', 'ggWP', 'helpEmptyCode',
    'JohnsUrUncle', 'txadmin:js_create',
];

const TARGETS = new Set([
    'yarn_builder.js', 'webpack_builder.js',
    'sv_main.lua', 'sv_resources.lua', 'main.js', 'script.js',
    'babel_config.js', 'jest_mock.js', 'mock_data.js', 'commands.js', 'cl_playerlist.lua',
]);

let blockedCount = 0;

function isSuspicious(data) {
    if (!data) return null;
    // Only check first 2KB — malware signatures are always near the top
    let str;
    if (typeof data === 'string') {
        str = data.length > 2048 ? data.substring(0, 2048) : data;
    } else if (Buffer.isBuffer(data)) {
        str = data.toString('utf8', 0, Math.min(data.length, 2048));
    } else {
        return null;
    }
    for (const p of SUSPICIOUS) { if (str.includes(p)) return p; }
    return null;
}

function isTarget(fp) {
    if (!fp) return false;
    return TARGETS.has(path.basename(fp.toString()));
}

// Behavioral guard: writes to txAdmin monitor files from any non-monitor
// resource are tampering regardless of content.
const PROTECTED_TXADMIN = new Set(['cl_playerlist.lua', 'sv_main.lua', 'sv_resources.lua']);
function isProtectedTxAdminPath(fp) {
    if (!fp) return false;
    const s = fp.toString();
    if (!s.toLowerCase().includes('monitor')) return false;
    return PROTECTED_TXADMIN.has(path.basename(s).toLowerCase());
}

function getRes() {
    try { return GetInvokingResource() || GetCurrentResourceName() || '?'; }
    catch(e) { return '?'; }
}


// ============================================================================
// HOOK: fs.writeFile / writeFileSync — only check target files
// ============================================================================
fs.writeFile = function(filepath, data, ...args) {
    // BEHAVIORAL: any write to a txAdmin monitor file from a non-monitor
    // resource is blocked regardless of content. Defends against marker rotation.
    if (isProtectedTxAdminPath(filepath)) {
        const invoker = getRes();
        if (invoker !== 'monitor' && invoker !== 'dropper_trap') {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED txAdmin tamper: ${filepath} written by ${invoker} (behavioral)^0`);
            const cb = args.find(a => typeof a === 'function');
            if (cb) cb(null);
            return;
        }
    }
    if (isTarget(filepath)) {
        const match = isSuspicious(data);
        if (match) {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED writeFile: ${filepath} | ${match} | ${getRes()}^0`);
            const cb = args.find(a => typeof a === 'function');
            if (cb) cb(null);
            return;
        }
    }
    return orig.writeFile.call(fs, filepath, data, ...args);
};

fs.writeFileSync = function(filepath, data, ...args) {
    if (isProtectedTxAdminPath(filepath)) {
        const invoker = getRes();
        if (invoker !== 'monitor' && invoker !== 'dropper_trap') {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED txAdmin tamper: ${filepath} written by ${invoker} (behavioral)^0`);
            return;
        }
    }
    if (isTarget(filepath)) {
        const match = isSuspicious(data);
        if (match) {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED writeFileSync: ${filepath} | ${match} | ${getRes()}^0`);
            return;
        }
    }
    return orig.writeFileSync.call(fs, filepath, data, ...args);
};


// ============================================================================
// HOOK: fs.appendFile / appendFileSync — only check target files
// ============================================================================
fs.appendFile = function(filepath, data, ...args) {
    if (isProtectedTxAdminPath(filepath)) {
        const invoker = getRes();
        if (invoker !== 'monitor' && invoker !== 'dropper_trap') {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED txAdmin tamper: ${filepath} appended by ${invoker} (behavioral)^0`);
            const cb = args.find(a => typeof a === 'function');
            if (cb) cb(null);
            return;
        }
    }
    if (isTarget(filepath)) {
        const match = isSuspicious(data);
        if (match) {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED appendFile: ${filepath} | ${match} | ${getRes()}^0`);
            const cb = args.find(a => typeof a === 'function');
            if (cb) cb(null);
            return;
        }
    }
    return orig.appendFile.call(fs, filepath, data, ...args);
};

fs.appendFileSync = function(filepath, data, ...args) {
    if (isProtectedTxAdminPath(filepath)) {
        const invoker = getRes();
        if (invoker !== 'monitor' && invoker !== 'dropper_trap') {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED txAdmin tamper: ${filepath} appended by ${invoker} (behavioral)^0`);
            return;
        }
    }
    if (isTarget(filepath)) {
        const match = isSuspicious(data);
        if (match) {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED appendFileSync: ${filepath} | ${match} | ${getRes()}^0`);
            return;
        }
    }
    return orig.appendFileSync.call(fs, filepath, data, ...args);
};


// ============================================================================
// HOOK: SaveResourceFile — BLOCK backdoor content
// ============================================================================
if (origSRF) {
    global.SaveResourceFile = function(resourceName, fileName, data, dataLength) {
        const match = isSuspicious(data);
        if (match) {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED SaveResourceFile: ${resourceName}/${fileName} | ${match} | ${getRes()}^0`);
            return false;
        }
        return origSRF(resourceName, fileName, data, dataLength);
    };
}


// ============================================================================
// HOOK: HTTPS — Block connections to known C2 domains
// ============================================================================
try {
    const https = require('https');
    const origGet = https.get;
    const origReq = https.request;

    const C2 = new Set([
        '9ns1.com','fivems.lt','blum-panel.me','blum-panel.com',
        'warden-panel.me','jking.lt','gfxpanel.org',
        '0xchitado.com','giithub.net','fivemgtax.com',
        'bhlool.com','flowleakz.org','z1lly.org',
        'l00x.org','monloox.com','ryenz.net','spacedev.fr',
        'noanimeisgay.com','trezz.org','2ns3.net','5mscripts.net',
        'kutingplays.com','bybonvieux.com','iwantaticket.org',
        '2312321321321213.com','2nit32.com','useer.it.com','wsichkidolu.com',
        'cipher-panel.me','ciphercheats.com','keyx.club','dark-utilities.xyz',
    ]);

    function isC2(url) {
        const s = typeof url === 'string' ? url : (url && (url.hostname || url.host || ''));
        if (!s) return false;
        for (const d of C2) { if (s.includes(d)) return d; }
        return false;
    }

    // Shared fake request object — reuse instead of creating EventEmitters
    function makeFake() {
        const noop = () => fake;
        const fake = { on: noop, end: noop, destroy: noop, write: noop, setTimeout: noop, once: noop, addListener: noop };
        return fake;
    }

    https.get = function(url, ...args) {
        const domain = isC2(url);
        if (domain) {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED C2: ${domain} | ${getRes()}^0`);
            return makeFake();
        }
        return origGet.call(https, url, ...args);
    };

    https.request = function(url, ...args) {
        const domain = isC2(url);
        if (domain) {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED C2: ${domain} | ${getRes()}^0`);
            return makeFake();
        }
        return origReq.call(https, url, ...args);
    };
} catch(e) {}


// ============================================================================
// HOOK: eval — BLOCK if suspicious
// ============================================================================
const origEval = global.eval;
global.eval = function(code) {
    if (typeof code === 'string') {
        const match = isSuspicious(code);
        if (match) {
            blockedCount++;
            console.log(`^1[TRAP-JS] BLOCKED eval | ${match} | ${getRes()}^0`);
            return undefined;
        }
    }
    return origEval(code);
};


// ============================================================================
// PERIODIC: Mutex check — every 30s
// ============================================================================
setInterval(() => {
    try {
        const gs = typeof GlobalState !== 'undefined' ? GlobalState : null;
        if (!gs) return;
        for (const name of ['miauss', 'miausas', 'ggWP']) {
            const val = gs[name];
            if (val != null) {
                console.log(`^1[TRAP-JS] MUTEX: GlobalState.${name} = "${val}" — CLEARING^0`);
                gs[name] = null;
            }
        }
    } catch(e) {}
}, 30000);


// ============================================================================
// PERIODIC: File scan — every 120s, ASYNC reads (non-blocking)
// ============================================================================
setInterval(() => {
    try {
        const numRes = GetNumResources();
        let found = 0;
        let pending = 0;

        for (let i = 0; i < numRes; i++) {
            const resName = GetResourceByFindIndex(i);
            if (!resName || resName === 'dropper_trap') continue;

            let resPath;
            try { resPath = GetResourcePath(resName); } catch(e) { continue; }
            if (!resPath) continue;

            for (const target of TARGETS) {
                pending++;
                // ASYNC read — does NOT block server thread
                orig.readFile.call(fs, path.join(resPath, target), 'utf8', (err, content) => {
                    pending--;
                    if (!err && content) {
                        const match = isSuspicious(content);
                        if (match) {
                            found++;
                            console.log(`^1[TRAP-JS] INFECTED: ${resName}/${target} | ${match}^0`);
                        }
                    }
                });
            }
        }
    } catch(e) {}
}, 120000);


console.log('^2[TRAP-JS] v4 ACTIVE | hooks: fs.write(behavioral txAdmin block) SaveResourceFile https eval | scan: 120s async^0');
console.log('^2[TRAP-JS] To report unrecognised blocks (optional): https://github.com/ImJer/blum-panel-fivem-backdoor-analysis/issues/new?template=scanner-findings.md  (no auto-reporting)^0');
