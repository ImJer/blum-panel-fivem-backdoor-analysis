// ============================================================================
// DROPPER TRAP v3 — JavaScript Hooks (OPTIMIZED)
// ============================================================================
// Changes from v2:
//   - File scan every 120s instead of 15s, uses async readFile not readFileSync
//   - Mutex check every 30s instead of 10s
//   - isSuspicious only scans first 2KB of data (patterns always in header)
//   - No toString() on large Buffers
//   - Added ggWP replicator mutex
//   - Removed excessive console.log spam (single-line alerts)
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
    'miauss', 'miausas', 'fivems.lt', 'RESOURCE_EXCLUDE',
    'isExcludedResource', 'onServerResourceFail', 'decompressFromUTF16',
    '\u15E1', 'blum-panel', 'ggWP', 'helpEmptyCode', 'JohnsUrUncle', 'txadmin:js_create',
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

function getRes() {
    try { return GetInvokingResource() || GetCurrentResourceName() || '?'; }
    catch(e) { return '?'; }
}


// ============================================================================
// HOOK: fs.writeFile / writeFileSync — only check target files
// ============================================================================
fs.writeFile = function(filepath, data, ...args) {
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
        'fivems.lt','0xchitado.com','giithub.net','fivemgtax.com',
        'warden-panel.me','bhlool.com','flowleakz.org','z1lly.org',
        'l00x.org','monloox.com','ryenz.net','spacedev.fr',
        'noanimeisgay.com','trezz.org','2ns3.net','5mscripts.net',
        'kutingplays.com','bybonvieux.com','iwantaticket.org','jking.lt',
        '2312321321321213.com','2nit32.com','useer.it.com','wsichkidolu.com',
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


console.log('^2[TRAP-JS] v3 ACTIVE | hooks: fs.write, SaveResourceFile, https, eval | scan: 120s async^0');
