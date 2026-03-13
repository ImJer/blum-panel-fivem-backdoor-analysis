// ============================================================================
// DROPPER TRAP v2 — JavaScript Hooks (BLOCKS + LOGS)
// ============================================================================
// BLOCKS malicious writes. Clean writes pass through normally.
// ============================================================================

const fs = require('fs');
const path = require('path');

const orig = {
    writeFile: fs.writeFile,
    writeFileSync: fs.writeFileSync,
    appendFile: fs.appendFile,
    appendFileSync: fs.appendFileSync,
    createWriteStream: fs.createWriteStream,
};

const origSRF = global.SaveResourceFile;

const SUSPICIOUS = [
    'String.fromCharCode', 'fromCharCode', 'bertjj', 'bertJJ',
    'miauss', 'miausas', 'fivems.lt', 'RESOURCE_EXCLUDE',
    'isExcludedResource', 'onServerResourceFail', 'decompressFromUTF16',
    '\u15E1', 'eval(d', '^k);', 'base91',
];

const TARGETS = [
    'yarn_builder.js', 'webpack_builder.js',
    'sv_main.lua', 'sv_resources.lua', 'main.js', 'script.js',
];

let blockedCount = 0;

function isSuspicious(data) {
    if (!data) return null;
    const str = typeof data === 'string' ? data : data.toString();
    for (const p of SUSPICIOUS) { if (str.includes(p)) return p; }
    return null;
}

function isTarget(fp) {
    if (!fp) return false;
    const name = path.basename(fp.toString());
    return TARGETS.some(t => name === t);
}

function getRes() {
    try { return GetInvokingResource() || GetCurrentResourceName() || 'unknown'; }
    catch(e) { return 'unknown'; }
}

function logBlock(method, filepath, pattern, data) {
    blockedCount++;
    console.log('^1======================================================================^0');
    console.log('^1[TRAP-JS] ████ DROPPER WRITE BLOCKED ████^0');
    console.log(`^1[TRAP-JS] Method:    ${method}^0`);
    console.log(`^1[TRAP-JS] File:      ${filepath}^0`);
    console.log(`^1[TRAP-JS] Resource:  ${getRes()}^0`);
    console.log(`^1[TRAP-JS] Pattern:   ${pattern}^0`);
    if (data) console.log(`^1[TRAP-JS] Preview:   ${(typeof data === 'string' ? data : data.toString()).substring(0, 150)}^0`);
    console.log(`^1[TRAP-JS] Stack:^0`);
    console.log(new Error().stack.split('\n').slice(2, 6).join('\n'));
    console.log(`^1[TRAP-JS] Total blocks: ${blockedCount}^0`);
    console.log('^1======================================================================^0');
}


// ============================================================================
// HOOK: fs.writeFile — BLOCK if malicious
// ============================================================================
fs.writeFile = function(filepath, data, ...args) {
    const match = isSuspicious(data);
    const target = isTarget(filepath);

    if (match && target) {
        logBlock('fs.writeFile', filepath, match, data);
        // Call the callback with no error so the dropper thinks it succeeded
        const cb = args.find(a => typeof a === 'function');
        if (cb) cb(null);
        return;
    }
    if (match || target) {
        console.log(`^3[TRAP-JS] WARNING: fs.writeFile → ${filepath} by "${getRes()}" (${match || 'known target'})^0`);
    }
    return orig.writeFile.call(fs, filepath, data, ...args);
};

fs.writeFileSync = function(filepath, data, ...args) {
    const match = isSuspicious(data);
    const target = isTarget(filepath);

    if (match && target) {
        logBlock('fs.writeFileSync', filepath, match, data);
        return; // Silently block — dropper thinks it succeeded
    }
    return orig.writeFileSync.call(fs, filepath, data, ...args);
};


// ============================================================================
// HOOK: fs.appendFile — BLOCK if malicious
// ============================================================================
fs.appendFile = function(filepath, data, ...args) {
    const match = isSuspicious(data);
    const target = isTarget(filepath);

    if (match && target) {
        logBlock('fs.appendFile', filepath, match, data);
        const cb = args.find(a => typeof a === 'function');
        if (cb) cb(null);
        return;
    }
    return orig.appendFile.call(fs, filepath, data, ...args);
};

fs.appendFileSync = function(filepath, data, ...args) {
    const match = isSuspicious(data);
    const target = isTarget(filepath);

    if (match && target) {
        logBlock('fs.appendFileSync', filepath, match, data);
        return;
    }
    return orig.appendFileSync.call(fs, filepath, data, ...args);
};


// ============================================================================
// HOOK: SaveResourceFile — BLOCK if malicious
// ============================================================================
if (typeof SaveResourceFile === 'function') {
    global.SaveResourceFile = function(resourceName, fileName, data, dataLength) {
        const match = isSuspicious(data);
        const target = isTarget(fileName);

        if (match) {
            logBlock('SaveResourceFile', `${resourceName}/${fileName}`, match, data);
            return false; // Block
        }
        return origSRF(resourceName, fileName, data, dataLength);
    };
}


// ============================================================================
// HOOK: HTTPS — Log and BLOCK connections to known C2 domains
// ============================================================================
try {
    const https = require('https');
    const origGet = https.get;
    const origReq = https.request;

    const C2 = ['fivems.lt','0xchitado.com','giithub.net','fivemgtax.com',
        'warden-panel.me','bhlool.com','flowleakz.org','z1lly.org',
        'l00x.org','monloox.com','ryenz.net','spacedev.fr',
        'noanimeisgay.com','trezz.org','2ns3.net','5mscripts.net',
        'kutingplays.com','bybonvieux.com','iwantaticket.org','jking.lt',
        '2312321321321213.com','2nit32.com','useer.it.com','wsichkidolu.com'];

    function checkC2(url) {
        const s = typeof url === 'string' ? url : (url.hostname || url.host || '');
        for (const d of C2) {
            if (s.includes(d)) {
                blockedCount++;
                console.log('^1[TRAP-JS] ████ C2 CONNECTION BLOCKED ████^0');
                console.log(`^1[TRAP-JS] URL:      ${s}^0`);
                console.log(`^1[TRAP-JS] Domain:   ${d}^0`);
                console.log(`^1[TRAP-JS] Resource: ${getRes()}^0`);
                console.log(new Error().stack.split('\n').slice(2, 5).join('\n'));
                return true;
            }
        }
        return false;
    }

    https.get = function(url, ...args) {
        if (checkC2(url)) {
            // Return a fake request that immediately errors
            const EventEmitter = require('events');
            const fake = new EventEmitter();
            fake.end = () => {};
            fake.destroy = () => {};
            fake.setTimeout = () => {};
            fake.on = fake.addListener;
            setTimeout(() => fake.emit('error', new Error('blocked by dropper_trap')), 0);
            const cb = args.find(a => typeof a === 'function');
            // Don't call callback — let it error silently
            return fake;
        }
        return origGet.call(https, url, ...args);
    };

    https.request = function(url, ...args) {
        if (checkC2(url)) {
            const EventEmitter = require('events');
            const fake = new EventEmitter();
            fake.end = () => {};
            fake.destroy = () => {};
            fake.write = () => {};
            fake.setTimeout = () => {};
            fake.on = fake.addListener;
            setTimeout(() => fake.emit('error', new Error('blocked by dropper_trap')), 0);
            return fake;
        }
        return origReq.call(https, url, ...args);
    };
} catch(e) {}


// ============================================================================
// HOOK: eval — BLOCK if suspicious content
// ============================================================================
const origEval = global.eval;
global.eval = function(code) {
    const match = isSuspicious(code);
    if (match) {
        blockedCount++;
        console.log('^1[TRAP-JS] ████ MALICIOUS EVAL BLOCKED ████^0');
        console.log(`^1[TRAP-JS] Resource: ${getRes()}^0`);
        console.log(`^1[TRAP-JS] Pattern:  ${match}^0`);
        console.log(`^1[TRAP-JS] Code:     ${(typeof code === 'string' ? code : '').substring(0, 150)}^0`);
        return undefined; // Block execution
    }
    return origEval(code);
};


// ============================================================================
// PERIODIC: Scan for infections + check GlobalState
// ============================================================================
setInterval(() => {
    try {
        const gs = global.GlobalState || (typeof GlobalState !== 'undefined' ? GlobalState : null);
        if (!gs) return;
        for (const name of ['miauss', 'miausas']) {
            const val = gs[name];
            if (val !== undefined && val !== null) {
                console.log(`^1[TRAP-JS] ████ MUTEX FOUND: GlobalState.${name} = "${val}" — CLEARING ████^0`);
                gs[name] = null;
            }
        }
    } catch(e) {}
}, 10000);

setInterval(() => {
    try {
        const numRes = GetNumResources();
        for (let i = 0; i < numRes; i++) {
            const resName = GetResourceByFindIndex(i);
            if (!resName) continue;
            const resPath = GetResourcePath(resName);
            if (!resPath) continue;
            for (const target of TARGETS) {
                try {
                    const content = require('fs').readFileSync(path.join(resPath, target), 'utf-8');
                    const match = isSuspicious(content);
                    if (match) {
                        console.log(`^1[TRAP-JS] ████ INFECTED: ${resName}/${target} (${match}) ████^0`);
                    }
                } catch(e) {} // file doesn't exist
            }
        }
    } catch(e) {}
}, 15000);


console.log('^2[TRAP-JS] ============================================^0');
console.log('^2[TRAP-JS] Dropper trap v2 ACTIVE — BLOCKING MODE^0');
console.log('^2[TRAP-JS] File writes: BLOCKED if malicious content^0');
console.log('^2[TRAP-JS] C2 connections: BLOCKED (all known domains)^0');
console.log('^2[TRAP-JS] Malicious eval: BLOCKED^0');
console.log('^2[TRAP-JS] GlobalState mutex: auto-cleared every 10s^0');
console.log('^2[TRAP-JS] File scan: every 15s for known patterns^0');
console.log('^2[TRAP-JS] ============================================^0');
