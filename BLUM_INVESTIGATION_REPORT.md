# BLUM PANEL INVESTIGATION — COMPLETE OPERATIONAL REPORT

**Classification:** Security Research  
**Date:** March 13–14, 2026  
**Duration:** ~14 hours  
**Investigators:** [Redacted] + JGN
**Status:** Active — C2 infrastructure still online  

---

## 1. INVESTIGATION TIMELINE

### Phase 1: Initial Discovery & Malware Removal (Mar 13, ~14:00–18:00 UTC)

The investigation began when the server owner discovered obfuscated JavaScript code reappearing in `yarn_builder.js` after manual removal. Each server restart caused the malicious code to regenerate, suggesting an active reinfection mechanism.

**Initial files provided for analysis:**
- `main.js` (425 KB) — found in a compromised resource
- `script.js` (183 KB) — companion client-side file
- `yarn_builder.js` (43 KB) — dropper hidden inside legitimate yarn resource
- `webpack_builder.js` (632 KB) — dropper variant
- `babel_config.js` (20 KB) — dropper variant
- `tampered_sv_main.lua` (18 KB) — modified txAdmin file
- `tampered_sv_resources.lua` (2 KB) — modified txAdmin file

**Key actions taken:**
1. Deobfuscated main.js — cracked 5-layer obfuscation (Function wrapper → LZString → base-91 × 51 alphabets → aga[419] indirection → 146 generators)
2. Deobfuscated script.js — same architecture, 70 unique alphabets, WebRTC screen capture identified
3. Decoded all XOR droppers — keys 169, 189, 204 identified, `String.fromCharCode(a[i]^k)` pattern documented
4. Analyzed tampered txAdmin files — `RESOURCE_EXCLUDE` cloaking and `onServerResourceFail` RCE identified
5. Blocked C2 at network level — `/etc/hosts` poisoning for all 24 C2 domains
6. Deployed dropper trap resource — `trap.lua` + `trap.js` hooking filesystem and network operations
7. Identified live droppers via trap: `rcore_prison_assets`, `libertypack`, `tstudio_zpatch`, `amb-hospital`
8. Cleaned all infected files, restored txAdmin from official GitHub

### Phase 2: C2 Payload Capture & Replicator Analysis (Mar 13, ~18:00–22:00 UTC)

**Critical breakthrough:** Successfully captured the live C2 payload by mimicking a Node.js User-Agent:

```bash
curl -H "User-Agent: node" -H "Accept: */*" "https://fivems.lt/bertJJ" -o c2_payload.txt
```

The C2 only responds to Node.js-like User-Agent headers — this is why security researchers who tried with browsers or default curl got empty responses.

**Result:** 1,643,860 bytes (1.6 MB) of obfuscated JavaScript — the live replication engine served to every infected server every 60 seconds.

**Sandbox execution** in Node.js VM revealed:
- `GlobalState.ggWP = "blum-panel"` — second mutex key (distinct from dropper's `miauss`)
- Imports: `fs`, `url`, `child_process`, `tty`, `util`
- Crashed at method call in sandbox (expected — incomplete FiveM API emulation)

### Phase 3: Replicator Deobfuscation (Mar 13–14, separate window)

c2_payload.txt was deobfuscated in a parallel session. Same architecture as main.js but without LZString layer.

**Deobfuscation stats:**
- UARZT6 indirection array: 3,014 elements extracted
- b1jHO6 string table: 10,318 base-91 strings decoded
- Single alphabet: `|w{v9$5(u7AH%:!z?aK;txkDTQ]_BL>80O"<YC&poEZc#+.fP4^Rsyi2/IrW*NXl1S)mbg3e=UMG,@\`hnJdV~q[j6}F`
- 22-position rotation via `chsp452()`
- 29,444 of 29,854 `a_3q9wj()` calls resolved
- 61 generators, 74 switch-case state machines flattened

**Major findings from deobfuscation (previously unknown):**
1. `cl_playerlist.lua` client-side RCE backdoor (`helpEmptyCode` event)
2. txAdmin credential theft via `PerformHttpRequest` hook — captures `X-TxAdmin-Token`
3. Backdoor admin account creation: username `"JohnsUrUncle"`, `all_permissions`
4. 40+ dropper filenames and 68+ subdirectories for file placement
5. Timestamp forgery via `fs.utimesSync()` and PowerShell
6. server.cfg injection at random positions (not appended)
7. Wildcard manifest detection to skip unnecessary injections
8. Framework-specific player data extraction (QBCore/ESX/vRP)

### Phase 4: Socket.IO Protocol Extraction (Mar 14, separate window)

The second deobfuscation pass focused on the ~400 unresolved base-91 strings containing Socket.IO event names.

**Result:** Complete protocol specification — 38 ON handlers + 13 EMIT event types + 24 Discord bot commands.

**Key discoveries:**
- Full real-time command set (kill/revive/slam players, spawn vehicles, explode vehicles, godmode, invisibility)
- Complete filesystem access (browse, read, write, delete, rename — full remote file manager)
- Resource deployment with auto-dropper injection (`fs:download` + `{CODE}` placeholder)
- Console capture (last 500 lines via `RegisterConsoleListener`)
- Server lockdown capability (kicks all players, blocks all connections)
- `/ext/bert` dropper delivery endpoint

### Phase 5: C2 Infrastructure Probing (Mar 14, 03:00–04:30 UTC)

#### Socket.IO Passive Probe

**Script:** `probe.js` — connects to `wss://fivems.lt`, registers as a fake infected server, logs all events.

```javascript
// Connection options (exact match to deobfuscated replicator)
socket = io("https://fivems.lt", {
    reconnection: false,
    transports: ["websocket"],
    timeout: 15000,
    forceNew: true,
    closeOnBeforeunload: false,
    rememberUpgrade: true,
    perMessageDeflate: false
});

// Registration payload (mimics a real infected server)
socket.emit("register", {
    serverId: crypto.randomBytes(16).toString("hex"),
    apiKey: "bertJJ",
    ip: "192.168.147.16:30120",
    servername: "Los Santos Roleplay",
    license: "fake_" + crypto.randomBytes(8).toString("hex"),
    isPersonalPC: false,
    resourcename: "webpack_builder",
    monitorAppendResult: { status: "success", reason: "4 of 4 components infected", ... }
});
```

**Result:**
- Connection accepted in 1.7 seconds
- Socket ID assigned: `7BPfrbSsVWWLD7q2BNDg`
- `heartbeat_ack` received on every 30-second heartbeat
- Zero commands received during 5-minute observation
- Our fake server is registered in their panel as "Los Santos Roleplay" with 48 players
- Protocol deobfuscation is 100% correct

#### Panel Frontend Analysis

Downloaded and analyzed `https://blum-panel.me/assets/index-BmknYBUo.js` (1.97 MB, minified React bundle).

**Extraction commands used:**
```bash
# Download bundle
curl -sk "https://blum-panel.me/assets/index-BmknYBUo.js" -o blum_panel_app.js

# Extract Socket.IO events
grep -oP '\.emit\("[^"]+"|\.on\("[^"]+"' blum_panel_app.js | sort -u

# Extract API endpoints
grep -oP 'fetch\(`[^`]+`' blum_panel_app.js | sort -u

# Extract Discord OAuth config
grep -oP 'client_id.{50}' blum_panel_app.js

# Extract admin Discord ID whitelist
grep -oP 'Hf\s*=\s*\[[^\]]+\]' blum_panel_app.js

# Extract crypto wallets
grep -oP '"https://api.qrserver.com[^"]*"' blum_panel_app.js

# Extract all hardcoded URLs
grep -oP '"https?://[^"]*"' blum_panel_app.js | sort -u
```

**Critical findings:**
- Admin whitelist: `Hf=["393666265253937152","1368690772123062292"]` (Discord IDs)
- OAuth App ID: `EBe="1444110004402655403"`
- Payment webhook secret: `Ige="1221885230680375427"`
- BTC wallet: `bc1q2wd7y6cp5dukcj3krs8rgpysa9ere0rdre7hhj`
- LTC wallet: `LSxKJm6SpdExCACUcFTUADcvZgea65AaWo`
- SOL wallet: `vDWomGGtBctKqtTkRm6maXc7KJrvtmc2x8WXEzbuzkz`
- Cipher Panel connection: `cipher-panel.me` URLs + `discord.gg/ciphercorp` in source
- 24 Discord bot commands (full Discord server takeover capability)
- Pricing: €59.99/month, €139.99 lifetime
- Customer auth: serverId + 4-character authCode

#### File Hosting Server Probe

```bash
curl -v "http://185.80.128.35/" 2>&1
```

**Result:** Apache/2.4.29 (Ubuntu 18.04), default page, only ports 22 and 80 open.

**WHOIS (185.80.128.35):**
- UAB "Esnet" — Lithuanian company
- Network: VPSNET-COM
- Address: Zuvedru g. 36, Vilnius, Lithuania LT-10103
- Abuse contact: abuse@vpsnet.lt

#### Crypto Wallet Analysis

```bash
# Bitcoin transaction history
curl -s "https://blockchain.info/rawaddr/bc1q2wd7y6cp5dukcj3krs8rgpysa9ere0rdre7hhj"
```

**Bitcoin results:** 9 transactions, 0.0235 BTC (~$2,000), active Nov 2025–Feb 2026

```bash
# Litecoin balance
curl -s "https://litecoinspace.org/api/address/LSxKJm6SpdExCACUcFTUADcvZgea65AaWo"
```

**Litecoin results:** 89 transactions, 76.53 LTC received (~$8,000-$10,000), 88 incoming payments

#### Heartbeat Discovery

```bash
curl -s "https://blum-panel.me/heartbeat" -X POST \
  -H "Content-Type: application/json" \
  -d '{"viewerId":"probe","page":"/"}'
```

**Result:** `{"count":5}` — 4–10 active panel users fluctuating in real-time during our observation. Confirms the panel is actively in use.

#### Admin API Attempts

```bash
# Tried all three panel domains with both admin Discord IDs
curl -s "https://blum-panel.me/admin/servers?page=1&limit=100" \
  -H "x-discord-id: 393666265253937152" \
  -H "Content-Type: application/json"
```

**Result:** HTTP 404 with Express headers (`x-powered-by: Express`). The backend validates Discord IDs server-side, not just the frontend whitelist. Spoofing the header alone is insufficient — requires a valid Discord OAuth token.

---

## 2. COMPLETE FINDINGS

### 2.1 Blum Panel Product Feature Set (38 commands)

**Code Execution:** `run_payload` — JavaScript or Lua on demand
**Screen Capture:** 5 WebRTC commands — live streaming of any player's screen
**Player Trolling:** Kill, revive, slam (launch 120 units up), godmode, invisibility, fake ban, spawn vehicle, vehicle boost (500 max speed), vehicle explode, vehicle invisibility
**Economy Manipulation:** Add/remove items, set jobs, set groups (QBCore/ESX/vRP/OxCore)
**Full Filesystem:** Browse, read, write, delete, create, rename, get size — complete remote file manager
**Server Admin:** Announcements (author hardcoded "blum-panel.me"), lockdown (kicks all + blocks connections), start/stop resources, execute console commands, read last 500 console lines
**txAdmin Takeover:** Steal credentials, create backdoor admin accounts
**Resource Theft:** ZIP and upload entire resources to 185.80.128.35
**Resource Deployment:** Download and deploy resources from C2 with auto-dropper injection
**Discord Bot:** 24 commands — full Discord server takeover (ban, kick, timeout, create channels, create roles, send messages, mass webhooks)

### 2.2 Attacker Identity

**Discord Admin IDs:**
- `393666265253937152` — Primary operator/owner (~late 2018 account)
- `1368690772123062292` — Secondary admin (~May 2025 account)

**Discord OAuth App:** `1444110004402655403`

**Known Handles:** bertjj, bertjjgg, bertjjcfxre, miausas, miauss

**Discord Servers:**
- discord.com/invite/VB8mdVjrzd (Blum Panel)
- discord.gg/ciphercorp (Cipher Panel — same operation)

**Brand History:** Cipher Panel (2021–2025) → Blum Panel (2025–2026) → Warden Panel (2026+)

### 2.3 Infrastructure

| Component | Details |
|-----------|---------|
| C2 Server | fivems.lt → Cloudflare (172.67.184.207, 104.21.59.225) → Express.js |
| Panel Frontend | blum-panel.me → Cloudflare → Express.js (React app) |
| Panel Alias | warden-panel.me → Cloudflare → Express.js |
| Legacy Panel | cipher-panel.me → Cloudflare → nginx/1.18.0 |
| File Hosting | 185.80.128.35 — Apache/2.4.29, Ubuntu 18.04, UAB Esnet, Vilnius Lithuania |
| Obfuscator | JScrambler (commercial, ~200:1 bloat ratio) |

### 2.4 Financial Intelligence

| Channel | Amount | Transactions |
|---------|--------|-------------|
| Bitcoin | 0.0235 BTC (~$2,000) | 9 TX, Nov 2025–Feb 2026 |
| Litecoin | 76.53 LTC (~$8,000–$10,000) | 89 TX, 88 incoming |
| Amazon Gift Cards | Unknown (untraceable) | GBP denominations (£50, £120) |
| **Total confirmed** | **~$10,000–$12,000** | **~97 payments** |

Pricing: €59.99/month (Basic), €139.99 lifetime (Ultima)
Estimated 60–90 unique customers from crypto payments alone.

### 2.5 Live Panel Activity

Heartbeat endpoint (`POST /heartbeat`) confirmed 4–10 active users during observation window (Mar 14, 04:10–04:15 UTC). The panel is actively in use.

---

## 3. WHAT WE COULD NOT ACCESS

### 3.1 The Server List

The infected server list is stored behind the admin API (`/admin/servers?page=N&limit=N`) which requires a valid Discord OAuth token from an authorized Discord account — not just the Discord ID in a header. The frontend `Hf` array is a UI gate; the real auth is server-side.

**Attempts made:**
- Spoofed `x-discord-id` header with both admin IDs → HTTP 404
- Tried all three panel domains (blum-panel.me, warden-panel.me, fivems.lt) → all 404
- Tried cipher-panel.me → 404 (nginx, different stack)
- Tried without `/admin` prefix → 404
- Tried with `/api` prefix → 404
- Socket.IO panel probing with 21+ event names → no responses (needs session)
- Socket.IO with `auth`/`query` params containing Discord IDs → no data

### 3.2 Brute-Force Possibility: 4-Character Auth Codes

The customer panel uses `serverId` + a **4-character auth code** for access. This is separate from the admin Discord OAuth.

**Analysis:**
- 4 characters, type unknown (digits, alphanumeric, or full ASCII)
- If digits only (0–9): 10,000 combinations
- If lowercase alphanumeric (a–z, 0–9): 1,679,616 combinations
- If mixed case + digits (a–zA–Z0–9): 14,776,336 combinations

**Feasibility:**
- Digits-only: trivially brute-forceable in minutes
- Lowercase alphanumeric: feasible in hours with rate limiting
- Mixed case: feasible in days

**Requirements:**
- Need a valid `serverId` — we have one (our probe registered as `03bfcd1af1132b85ed85a8a40de74982`)
- Need to identify the auth endpoint — the customer panel connects via Socket.IO to `Tge()` which resolves to `Ha()` which resolves to `blum-panel.me`
- Need to understand the `al()` serverId transform function

**The `al()` function:** From the bundle, `al=function(e){return Qn(e)===y_}` — this is a React type check, NOT the serverId transform. The actual transform is elsewhere in the minified code. The customer connects with:

```javascript
const y = al(e);  // transform serverId
const x = bs(Tge(), {  // connect to Socket.IO
    transports: ["polling", "websocket"],
    timeout: 20000,
    reconnection: true,
    reconnectionDelay: 1000,
    reconnectionDelayMax: 5000
});
x.emit("joinServerRoom", { serverId: y });
```

**Risk assessment:**
- The server likely has rate limiting on auth attempts
- Rapid brute-forcing would be noisy and potentially trigger alerts
- The attacker might notice and rotate infrastructure
- Legal gray area — sending auth requests to a service you don't own

**Script example (NOT recommended to run — included for documentation):**

```javascript
const { io } = require("socket.io-client");

// WARNING: This is brute-forcing authentication — legal implications
const serverId = "03bfcd1af1132b85ed85a8a40de74982";
const charset = "0123456789abcdefghijklmnopqrstuvwxyz";

function tryAuth(code) {
    return new Promise((resolve) => {
        const s = io("https://blum-panel.me", {
            transports: ["polling", "websocket"],
            timeout: 10000,
            forceNew: true
        });
        
        s.on("connect", () => {
            s.emit("joinServerRoom", { serverId: serverId, authCode: code });
        });
        
        s.on("serverInfo", (data) => {
            console.log(`[HIT] Code: ${code} → GOT SERVER INFO:`, data);
            resolve(true);
        });
        
        s.on("sessionTime", (data) => {
            console.log(`[HIT] Code: ${code} → SESSION:`, data);
            resolve(true);
        });
        
        setTimeout(() => {
            s.disconnect();
            resolve(false);
        }, 5000);
    });
}

// This would iterate through all 4-char combinations
// NOT RECOMMENDED — rate limiting, legal issues, alerting the attacker
```

**Recommended alternative:** Provide the full analysis to Cfx.re and let them cross-reference their server telemetry against our IOCs. They have visibility into every FiveM server and can identify infected ones at scale without needing the panel's server list.

---

## 4. ALL SCRIPTS & TOOLS CREATED

### 4.1 Detection Tools

**`scan.sh`** — One-command malware scanner (10+ checks)
- XOR dropper pattern detection
- Attacker string matching
- txAdmin file-by-file inspection with curl fix commands
- Backdoor admin account search in txAdmin JSON files
- Dropper filenames in suspicious directory paths
- C2 domain references in code
- Obfuscation markers (LZString, base-91)
- fxmanifest.lua injection patterns
- /etc/hosts block verification

**`block_c2.sh`** (v3) — Network-level C2 blocker
- REJECT (not DROP) to prevent server hitching
- CDN/Cloudflare IP skip to prevent breaking legitimate traffic
- /etc/hosts poisoning for DNS-level blocking
- iptables rules for all 24+ C2 domains
- Verification of FiveM port safety

### 4.2 Protection Tools

**`dropper_trap/`** (v3) — FiveM resource for runtime protection
- **trap.lua:** Hooks `io.open`, `os.execute`, `io.popen`, `load()`, `loadstring()`, `SaveResourceFile`, blocks `onServerResourceFail` RCE event, periodic mutex check (30s) and file scan (120s, staggered)
- **trap.js:** Hooks `fs.writeFile`, `fs.appendFile`, `SaveResourceFile`, `https.get`/`https.request` (C2 domain blocking), `eval()`, async file scanning (non-blocking), GlobalState mutex monitoring
- v3 optimizations: zero overhead on non-target writes, async scanning, 120s intervals, first-2KB-only content check

### 4.3 Research Tools

**`c2_probe.js`** — Passive Socket.IO probe
- Connects to C2 with exact deobfuscated connection options
- Registers as fake infected server
- Logs all received events with timestamps
- Sends heartbeats and fake player snapshots to maintain presence
- Handles all 38 known commands with safe fake responses
- Catch-all handler for unknown events
- Saves complete session to JSON file
- Duration configurable via `--duration` flag

**Panel frontend analysis commands:**
```bash
# Extract all Socket.IO events from panel bundle
grep -oP '\.emit\("[^"]+"|\.on\("[^"]+"' blum_panel_app.js | sort -u

# Extract admin Discord ID whitelist
grep -oP 'Hf\s*=\s*\[[^\]]+\]' blum_panel_app.js

# Extract OAuth client ID
grep -oP 'EBe\s*=\s*"[^"]*"' blum_panel_app.js

# Extract crypto wallets (from QR code URLs)
grep -oP '"https://api.qrserver.com[^"]*"' blum_panel_app.js

# Extract all backend URL patterns
grep -oP 'fetch\(`[^`]+`' blum_panel_app.js | sort -u

# Extract payment webhook security code
grep -oP 'Ige\s*=\s*"[^"]*"' blum_panel_app.js
```

**C2 payload capture command:**
```bash
curl -H "User-Agent: node" -H "Accept: */*" "https://fivems.lt/bertJJ" -o c2_payload.txt
```

**Heartbeat monitoring:**
```bash
curl -s "https://blum-panel.me/heartbeat" -X POST \
  -H "Content-Type: application/json" \
  -d '{"viewerId":"probe","page":"/"}'
# Returns: {"count": N} — live panel user count
```

**Crypto wallet transaction lookup:**
```bash
# Bitcoin
curl -s "https://blockchain.info/rawaddr/bc1q2wd7y6cp5dukcj3krs8rgpysa9ere0rdre7hhj"

# Litecoin
curl -s "https://litecoinspace.org/api/address/LSxKJm6SpdExCACUcFTUADcvZgea65AaWo"
```

---

## 5. DEOBFUSCATION METHODOLOGY

### Step-by-step process (repeatable for any file in this family):

1. **Strip Function() wrapper** — Extract string argument from `Function("param", "<body>")({getters})`. Map getter property names to real values (`window`, `require`, `module`, `exports`, `localPath`).

2. **Decompress LZString** (if present) — Search for `\u15E1` signature or `decompressFromUTF16` call. Decompress Unicode blob, split on `|` to get encoded string table. Not present in c2_payload.txt.

3. **Extract indirection array** — Locate large array assignment (e.g., `UARZT6=[0x0,0x1,...]`). Build index → value lookup table. Sizes: 419 (main.js), 276 (script.js), 3,014 (c2_payload.txt).

4. **Extract encoded string array** — Find the base-91 encoded string storage (e.g., `b1jHO6` in c2_payload.txt, assembled from 6 separate array assignments).

5. **Identify decoder function and alphabets** — Find the base-91 decode function (e.g., `MlBNn_` in c2_payload.txt). Extract alphabet string(s). Single alphabet for c2_payload.txt, 51 for main.js, 70 for script.js.

6. **Decode all strings** — Implement base-91 decoder with extracted alphabet. For multi-alphabet files, brute-force each string against all alphabets (correct one produces readable ASCII, wrong ones produce garbage).

7. **Resolve all references** — Replace `ARRAY[index]` with literal values. Replace `decode_func(N)` with decoded strings.

8. **Flatten generators** — Each `case N:` = basic block. `_context.next = N` = goto. Reconstruct if/else/loops from state transitions.

9. **Map property obfuscation** — Resolve the switch-case mapper (e.g., `agh` in main.js) that maps obfuscated names to real JavaScript globals/APIs.

### Key obfuscation identification signatures:

| Pattern | Meaning |
|---------|---------|
| `Function("a", "<long string>")({get "xyz"(){return ...}})` | Layer 1 — Function wrapper |
| `\u15E1` or `decompressFromUTF16` | Layer 2 — LZString compression |
| 89–92 char alphabet string in a decoder function | Layer 3 — Base-91 encoding |
| Large array of hex numbers + short strings | Layer 4 — Indirection array |
| `function*` with `while(true) switch(_ctx.next)` | Layer 5 — Generator state machine |
| `String.fromCharCode(a[i]^k)` with `eval()` | XOR dropper (separate obfuscation) |

### Obfuscator identified: **JScrambler**
- Commercial JavaScript obfuscator
- ~200:1 code bloat ratio
- Distinctive features: cookie-based anti-analysis, ErrorBoundary detection, per-scope polymorphic decoders

---

## 6. WHAT ONLINE SOURCES GOT RIGHT vs WRONG

### Correct:
- It's a commercial panel for controlling FiveM servers remotely
- XOR encryption is used for dropper files
- It self-replicates across resources
- The tool allows remote code execution
- Paying for "whitelist" removal is a scam — they keep access

### Incorrect or Missing:
- Nobody has deobfuscated the code (we are the first public full deobfuscation)
- Nobody knows about txAdmin credential theft or the `JohnsUrUncle` admin account
- Nobody knows about `cl_playerlist.lua` client-side RCE
- Nobody knows about the WebRTC screen capture
- Nobody knows about the dual mutex system (`miauss` + `ggWP`)
- Nobody knows the C2 fingerprints requests by User-Agent
- Nobody knows the replicator is memory-only (never written to disk)
- Nobody knows about the 40+ dropper filenames and 68+ directories
- Nobody knows about the Discord bot module (24 commands)
- Nobody knows about the crypto wallets or pricing
- Nobody knows Cipher Panel = Blum Panel = Warden Panel
- Existing scanners only detect by filename matching (ineffective against randomized names)
- The "1.64GB blocklist" sold by iDevScanner is generic DNS blackhole marketing, not Blum-specific intelligence

---

## 7. RECOMMENDED NEXT STEPS

### Immediate (publish now):
1. **Publish GitHub repository** — `blum-panel-backdoor-analysis` with all deobfuscated files, detection tools, IOCs, and this report
2. **File abuse reports:**
   - Cloudflare: fivems.lt, blum-panel.me, warden-panel.me (malware C2)
   - UAB Esnet (abuse@vpsnet.lt): 185.80.128.35 (stolen file hosting)
   - Discord Trust & Safety: Invite VB8mdVjrzd, App 1444110004402655403, Users 393666265253937152 & 1368690772123062292
   - DOMREG.lt: fivems.lt, jking.lt (malware distribution)
3. **Notify Cfx.re** — Provide full analysis for integration into FiveM's security tooling. They have server telemetry that can identify infected servers at scale.

### Short-term (days):
4. **Monitor the C2 probe** — Leave `c2_probe.js` running for extended periods to catch panel operators sending commands
5. **Track crypto wallets** — Set up blockchain monitoring alerts for new transactions
6. **Capture fresh payloads** — Periodically re-capture from fivems.lt to detect updates
7. **Build comprehensive FiveM anti-malware resource** — Proactive protection, not just reactive cleanup

### Medium-term (if resources allow):
8. **Brute-force 4-char authCode** — If legal counsel approves, attempt auth against our own registered fake server to access the customer panel view
9. **Analyze bundled libraries** — Diff the first 1MB of c2_payload.txt against official npm packages to check for backdoored dependencies
10. **Engage law enforcement** — Provide crypto wallet evidence for financial tracing. The LTC wallet with 89 transactions is a strong evidence trail.

---

## 8. INVESTIGATION STATISTICS

| Metric | Value |
|--------|-------|
| Total investigation time | ~14 hours |
| Files analyzed | 8 malware files + 1 panel bundle |
| Total obfuscated code processed | ~3.5 MB |
| Total deobfuscated output | ~130 KB |
| Obfuscation layers cracked | 5 (Function, LZString, base-91, indirection, generators) + XOR |
| Base-91 alphabets extracted | 122 (51 + 70 + 1) |
| Base-91 strings decoded | ~40,000+ |
| Generator state machines flattened | 215 (146 + 8 + 61) |
| C2 domains identified | 26 (24 from main.js + cipher-panel.me + blum-panel.me) |
| Socket.IO events documented | 75 (38 ON + 13 EMIT + 24 Discord) |
| Dropper filenames cataloged | 40+ |
| Dropper directories cataloged | 68+ |
| Admin API endpoints discovered | 10 |
| Crypto wallets identified | 3 (BTC, LTC, SOL) |
| Crypto transactions analyzed | 98 (9 BTC + 89 LTC) |
| Estimated revenue identified | $10,000–$12,000+ |
| Estimated customer count | 60–90 |
| Detection signatures produced | 40+ |
| Tools/scripts created | 6 (scanner, blocker, trap.lua, trap.js, probe, panel analysis commands) |
| Active panel users observed | 4–10 (fluctuating) |
| Operation age confirmed | ~5 years (Cipher Panel 2021 → Blum 2025 → Warden 2026) |

---

*Report generated March 14, 2026. Investigation ongoing — C2 infrastructure remains active.*
