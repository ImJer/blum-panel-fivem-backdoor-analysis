<p align="center">
  <h1 align="center">Blum Panel Backdoor</h1>
  <h3 align="center">Complete Deobfuscation & Threat Analysis</h3>
  <p align="center">
    The first public full reverse-engineering of the Blum Panel / Warden Panel FiveM backdoor<br>
    and its connection to the Cipher Panel operation.
  </p>
  <p align="center">
    <strong>Research by Justice Gaming Network (JGN)</strong><br>
    FiveM Server: <strong>JusticeRP</strong> &mdash; <a href="https://discord.gg/JRP">discord.gg/JRP</a>
  </p>
</p>

---

> **Every obfuscation layer cracked. Every C2 endpoint mapped. Every payload decoded.**
> This repository contains deobfuscated source code, detection tools, C2 protocol specifications,
> attacker identity intelligence, and a complete investigation report covering a ~16-hour
> reverse engineering effort conducted March 13-14, 2026.

---

## Quick Start — Is My Server Infected?

**Run the scanner** from your FiveM server root directory:

```bash
chmod +x scan.sh && ./scan.sh
```

**Check for active infection** in your FiveM server console:

```lua
-- Paste into server console or txAdmin Live Console
if GlobalState.miauss then print("DROPPER ACTIVE: "..GlobalState.miauss) end
if GlobalState.ggWP then print("REPLICATOR ACTIVE: "..GlobalState.ggWP) end
```

**Block the C2 immediately:**

```bash
chmod +x block_c2.sh && ./block_c2.sh
```

If anything triggers, read the [Detection and Remediation](#detection-and-remediation) section below.

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Research Attribution](#research-attribution)
- [The Cipher Panel Connection](#the-cipher-panel-connection)
- [The Complete Kill Chain](#the-complete-kill-chain)
- [Files Analyzed](#files-analyzed)
- [Obfuscation Architecture](#obfuscation-architecture)
- [C2 Infrastructure](#c2-infrastructure)
- [Malware Components](#malware-components)
  - [C2 Loader (main.js)](#1-c2-loader-mainjs)
  - [Screen Capture (script.js)](#2-screen-capture-scriptjs)
  - [Live Replicator (c2_payload.txt)](#3-live-replicator-c2_payloadtxt)
  - [txAdmin Tampering](#4-txadmin-tampering)
  - [XOR Droppers](#5-xor-droppers)
  - [Luraph Lua Payloads](#6-luraph-lua-payloads)
- [Panel Architecture](#panel-architecture)
- [Discord Bot Module](#discord-bot-module)
- [Attacker Identity and Financial Intelligence](#attacker-identity-and-financial-intelligence)
- [C2 Probe Results](#c2-probe-results)
- [Detection and Remediation](#detection-and-remediation)
- [Repository Structure](#repository-structure)
- [Reporting Contacts](#reporting-contacts)

---

## Executive Summary

**Blum Panel** is a commercial FiveM backdoor sold for EUR 59.99/month or EUR 139.99 lifetime. It gives paying customers full remote control over infected FiveM servers — code execution, live screen capture, player manipulation, economy exploitation, full filesystem access, and complete server lockdown.

### What the FiveM community didn't know until this analysis

| Finding | Details |
|---------|---------|
| **Stolen codebase** | Blum Panel is built on stolen Cipher Panel code. Cipher's creator publicly called it "Cipher copy-pasta" on Feb 4, 2026. |
| **Two infection languages** | JavaScript (JScrambler) AND Lua (Luraph v14.6). Existing scanners only check for JS. |
| **Two C2 domains** | `fivems.lt` (primary) and `9ns1.com` (secondary — first documented here). |
| **Four API keys** | `bert`, `dev`, `null`, `zXeAH` — each with dedicated C2 endpoints. |
| **Memory-only replicator** | The 1.6MB payload is fetched and eval'd every 60 seconds. Never touches disk. |
| **txAdmin credential theft** | Steals `X-TxAdmin-Token`, creates backdoor admin "JohnsUrUncle" with `all_permissions`. |
| **Live screen capture** | WebRTC streaming of any connected player's screen to the attacker. |
| **Two commercial obfuscators** | JScrambler (~$100/mo) for JS + Luraph v14.6 (~$20/mo) for Lua. |
| **$10,000+ crypto revenue** | Tracked across Bitcoin and Litecoin wallets. 88 customer payments identified. |
| **Panel is actively in use** | 4-10 users observed online during our investigation. |

---

## Research Attribution

This research was conducted by the **Justice Gaming Network (JGN)** team, operators of the **JusticeRP** FiveM server.

**Join us:** [discord.gg/JRP](https://discord.gg/JRP)

The investigation started when Blum Panel artifacts were found on the JusticeRP server on March 13, 2026. Over 16 hours, the JGN team:

- Reverse-engineered 11 obfuscated malware files across two languages
- Captured and decoded the live 1.6MB C2 replicator payload
- Probed the attacker's infrastructure and registered a fake server in their panel
- Analyzed the panel frontend bundle (1.97MB React app)
- Traced cryptocurrency payments across Bitcoin and Litecoin
- Identified attacker Discord accounts, OAuth apps, and Discord webhooks
- Discovered a second C2 domain (`9ns1.com`) and the entire Lua infection pathway

**Firsts accomplished by JGN:**

- First public deobfuscation of any Blum Panel or Cipher Panel file
- First identification of the Lua infection pathway (Luraph payloads)
- First discovery of the second C2 domain `9ns1.com`
- First extraction of the Discord phone-home webhook
- First complete Socket.IO protocol documentation (75 commands)
- First documentation of txAdmin credential theft and WebRTC screen capture
- First proof connecting Blum Panel code to Cipher Panel
- First extraction of attacker Discord IDs, crypto wallets, and OAuth app
- First successful C2 probe — registered a fake server in the attacker's panel

---

## The Cipher Panel Connection

### Background: Two Competing Criminal Operations

Our code analysis found `cipher-panel.me` URLs and `discord.gg/ciphercorp` references hardcoded inside the Blum Panel frontend bundle. This initially suggested Blum Panel was a rebrand of Cipher Panel. **Discord intelligence tells a different story.**

### The Evidence

On **February 4, 2026**, the Cipher Panel creator posted in their Discord server:

> *"Let's give a round of applause to **Blum-panel**, aka **Cipher copy-pasta**, for this incredible update!*
> *Those who thought they were above Cipher now find themselves at their rightful level.*
> *Stop buying copy-pasta panels; you're better off sticking with Cipher*
> ***CIPHER > ALL***"

The poster is **Authentic** (`authentic777`), Discord ID `1072311313080004648`, who holds the **CIPHER CREATOR** role and has `cipher-panel.me` displayed on their Discord profile.

### What This Means

**Blum Panel is not a rebrand — it's a code theft.** Someone took Cipher Panel's codebase, repackaged it as "Blum Panel" (and later "Warden Panel"), and set up competing infrastructure to sell it. This explains:

- **Why cipher-panel.me URLs appear in Blum's code** — the Blum developer forked Cipher's code but didn't clean out all references to the original.
- **Why the backends are different** — cipher-panel.me runs nginx/1.18.0 while blum-panel.me and warden-panel.me run Express.js. Different operators, different deployments.
- **Why Cipher's creator is hostile toward Blum** — their product was stolen and is undercutting their business.
- **Why the code quality is high** — Cipher Panel has been in development since 2021. Blum inherited 4+ years of feature development.

### Known Cipher Panel Intelligence

| Item | Value |
|------|-------|
| Creator | **Authentic** / `authentic777` |
| Discord ID | `1072311313080004648` (account created ~May 2022) |
| Domain | `cipher-panel.me` (nginx/1.18.0, Cloudflare) |
| Discord | `discord.gg/ciphercorp` |
| Active since | ~2021 (Cfx.re forum reports) |
| Role in Discord | "CIPHER CREATOR" + "Moderators" |
| Relationship to Blum | **Blum stole Cipher's codebase** — Authentic publicly confirmed Feb 4, 2026 |

### Known Blum Panel / Warden Panel Intelligence

| Item | Value |
|------|-------|
| Admin Discord IDs | `393666265253937152` (~2018 account), `1368690772123062292` (~May 2025) |
| Domains | `blum-panel.me`, `warden-panel.me` (Express.js, Cloudflare) |
| Discord | `discord.com/invite/VB8mdVjrzd` |
| OAuth App | `1444110004402655403` (name: "blum") |
| C2 Domains | `fivems.lt`, `9ns1.com` |
| Active since | Late 2025 (first crypto payment Nov 28, 2025) |
| Relationship to Cipher | **Stole Cipher Panel's codebase** — code contains cipher-panel.me URLs |

### The Bigger Picture

Both Cipher Panel and Blum Panel are **active criminal operations** selling unauthorized access to FiveM servers. The Cipher Panel creator's complaint about code theft is a dispute between criminals — neither operation is legitimate. Both should be reported and taken down.

The technical analysis in this repository applies to **both operations** since they share the same underlying codebase. Detection signatures and remediation steps will catch infections from either panel.

---

## The Complete Kill Chain

```
 INITIAL INFECTION (Two paths — JS or Lua)
 ──────────────────────────────────────────

  PATH A: JavaScript (yarn_builder.js, webpack_builder.js, etc.)
  ├── XOR-encrypted eval() fetches C2 loader (main.js, 425KB)
  └── main.js → setImmediate dropper → fetches replicator from C2

  PATH B: Lua (Luraph-obfuscated, 65KB)
  ├── Drops polymorphic XOR-encrypted JS file
  ├── Modifies fxmanifest.lua to load dropper on restart
  ├── Sends Discord webhook to attacker (infection notification)
  └── On restart → JS dropper → fetches replicator from C2

 STAGE 2: REPLICATOR (c2_payload.txt, 1.6MB — memory only)
 ──────────────────────────────────────────────────────────

  T+2s   Collect server info (framework, anticheats, license)
  T+3s   Infect server — 4 components:
         ├── XOR dropper injection into 40+ resource files
         ├── server.cfg injection at random position
         ├── txAdmin sv_main.lua tampering (hide from dashboard)
         └── txAdmin credential theft (X-TxAdmin-Token capture)
  T+32s  Connect to C2 via Socket.IO (wss://fivems.lt)

 STAGE 3: PERSISTENT BACKDOOR (Socket.IO — 39 event handlers)
 ─────────────────────────────────────────────────────────────

  ├── Arbitrary JS/Lua code execution
  ├── WebRTC live screen capture of any player
  ├── Player manipulation (kill, ban, godmode, spawn vehicles)
  ├── Economy manipulation (add/remove items, set jobs)
  ├── Full filesystem access (read, write, delete, browse)
  ├── Resource theft (ZIP + upload to attacker's server)
  ├── Console capture (last 500 lines)
  ├── Server lockdown (kick all + block all connections)
  ├── txAdmin admin creation ("JohnsUrUncle", all_permissions)
  └── Discord bot control (24 commands — take over Discord servers)
```

---

## Files Analyzed

| File | Size | Obfuscator | Purpose |
|------|------|------------|---------|
| `main.js` | 425 KB | JScrambler | C2 loader — fetches replicator |
| `script.js` | 183 KB | JScrambler | WebRTC screen capture client |
| `c2_payload.txt` | 1.64 MB | JScrambler | Live replicator — the core backdoor |
| `ext/bert` | 425 KB | JScrambler | Dropper served from C2 endpoint |
| `yarn_builder.js` | 43 KB | XOR (key 169) | Dropper hidden in yarn resource |
| `webpack_builder.js` | 632 KB | XOR (key 189) | Dropper hidden in webpack resource |
| `babel_config.js` | 20 KB | XOR (key 204) | Dropper hidden in babel resource |
| `sv_main.lua` | 18 KB | Tampered | txAdmin cloaking (RESOURCE_EXCLUDE) |
| `sv_resources.lua` | 2 KB | Tampered | txAdmin RCE backdoor |
| `/test` | 65 KB | Luraph v14.6 | Lua dropper → `9ns1.com/zXeAHJJ` |
| `/dev` | 64 KB | Luraph v14.6 | Lua dropper → `fivems.lt/devJJ` |
| `/null` | 64 KB | Luraph v14.6 | Lua dropper → `fivems.lt/nullJJ` |
| Panel bundle | 1.97 MB | Minified React | Customer/admin dashboard |

---

## Obfuscation Architecture

### JavaScript — JScrambler (5 Layers)

Commercial obfuscator (~$100/month). All JS files use the same pipeline:

| Layer | Technique | Details |
|-------|-----------|---------|
| 1 | Function() wrapper | `Function("a", "<body>")({get "xyz"(){return window}})` |
| 2 | LZString compression | UTF-16 compressed string table (signature `\u15E1`) |
| 3 | Base-91 encoding | 122 unique alphabets across all files, 40,000+ strings decoded |
| 4 | Indirection arrays | Up to 3,014 elements mapping indices to values |
| 5 | Generator state machines | 215 total generators with multi-variable dispatch |

**Bloat ratio:** ~200:1. The `/ext/bert` dropper is 425KB of obfuscation wrapping 50 lines of code.

### Lua — Luraph v14.6

Commercial obfuscator (~$20/month). Three unique payload builds:

- Custom bytecode VM with 140+ opcodes
- `pcall`-wrapped execution with "Luraph Script:" error prefix
- Embedded compressed bytecode in `LPH...` encoded strings
- `__index`/`__newindex` metatable isolation

### XOR Droppers

Simple `String.fromCharCode(a[i] ^ k)` with keys 169, 189, 204.
Decrypts to `eval()` fetching from C2 endpoints.

---

## C2 Infrastructure

### Domains

| Domain | Type | Backend | Location |
|--------|------|---------|----------|
| `fivems.lt` | Primary C2 | Express.js | Cloudflare (origin hidden) |
| `9ns1.com` | Secondary C2 | Unknown | **First documented by JGN** |
| `blum-panel.me` | Panel frontend | Express.js | Cloudflare |
| `warden-panel.me` | Panel alias | Express.js (identical to blum) | Cloudflare |
| `cipher-panel.me` | Original panel | nginx/1.18.0 | Cloudflare |
| `185.80.128.35` | File hosting | Apache/2.4.29 Ubuntu | UAB Esnet, Vilnius Lithuania |

### C2 Endpoints

| Endpoint | Type | API Key |
|----------|------|---------|
| `fivems.lt/bertJJ` | JS replicator (1.64MB) | bert |
| `fivems.lt/bertJJgg` | JS replicator fallback | bert |
| `fivems.lt/bertJJcfxre` | JS replicator fallback | bert |
| `fivems.lt/ext/bert` | JS dropper (425KB) | bert |
| `fivems.lt/devJJ` | JS replicator (Lua variant) | dev |
| `fivems.lt/nullJJ` | JS replicator (Lua variant) | null |
| `9ns1.com/zXeAHJJ` | JS replicator (secondary C2) | zXeAH |
| `fivems.lt/sendWebhooks` | Phone-home | — |
| `blum-panel.me/heartbeat` | Live user count | — |

The C2 **only responds** to requests with `User-Agent: node` and `Accept: */*`. Standard browser or curl requests return empty content — this is why other researchers got nothing.

23+ additional fallback domains are hardcoded in the replicator (full list in `iocs/domains.txt`).

### Socket.IO Protocol — 75 Commands

Full specification: [`iocs/socket_io_protocol.md`](iocs/socket_io_protocol.md)

| Category | Commands | Capabilities |
|----------|----------|-------------|
| Code Execution | 1 | Run arbitrary JavaScript or Lua |
| Screen Capture | 5 | WebRTC live streaming of player screens |
| Player Control | 10 | Kill, revive, slam, godmode, invisibility, vehicle control |
| Economy | 5 | Add/remove items, set jobs, set groups |
| Filesystem | 11 | Browse, read, write, delete, rename — full remote file manager |
| Server Admin | 3 | Announcements, lockdown, console commands |
| txAdmin | 1 | Steal credentials, create backdoor admin |
| Discord Bot | 24 | Ban, kick, timeout, create channels/roles, send messages |
| Telemetry | 13 | Server info, player snapshots, heartbeat |

---

## Malware Components

### 1. C2 Loader (main.js)

**Deobfuscated:** [`deobfuscated/deobfuscated_main.js`](deobfuscated/deobfuscated_main.js) (425 KB → 14 KB)

Delays execution with `setImmediate` → `setTimeout(15s)`. Checks `GlobalState.miauss` mutex to prevent duplicates. Fetches replicator from three C2 endpoints with retry logic (3 attempts, 5s backoff, 120s final backoff).

### 2. Screen Capture (script.js)

**Deobfuscated:** [`deobfuscated/deobfuscated_script.js`](deobfuscated/deobfuscated_script.js) (183 KB → 26 KB)

Client-side injection. Creates invisible full-screen canvas, captures via WebGL shaders, streams via WebRTC peer connections. LRU session management for multiple viewers.

### 3. Live Replicator (c2_payload.txt)

**Deobfuscated:** [`deobfuscated/c2_payload.js`](deobfuscated/c2_payload.js) (1.64 MB → 37 KB, 15 sections)

The core payload — fetched every 60 seconds, executed in memory, never written to disk:

- Server intelligence (14 fields: framework, anticheats, license, uptime, IP)
- Infection engine tracking 4 components across 40+ filenames and 68+ directories
- Timestamp forgery (`fs.utimesSync()` + PowerShell `LastWriteTime`)
- Windows stealth (`attrib +h +s +r`)
- Wildcard manifest detection
- Dual mutex (`GlobalState.ggWP` + `GlobalState.miauss`)
- Anticheat detection (9 products) and framework detection (QBCore/ESX/vRP/OxCore)

### 4. txAdmin Tampering

Four components target txAdmin (FiveM's standard management panel):

| Component | Purpose |
|-----------|---------|
| `sv_main.lua` | `RESOURCE_EXCLUDE` list (62+ names) hides malicious resources from dashboard |
| `sv_resources.lua` | `onServerResourceFail` RCE via `load(luaCode)` |
| `cl_playerlist.lua` | Client-side RCE via `helpEmptyCode` event (previously unknown) |
| `PerformHttpRequest` hook | Steals `X-TxAdmin-Token`, creates admin **"JohnsUrUncle"** with `all_permissions` |

### 5. XOR Droppers

| File | XOR Key | Decrypts To |
|------|---------|-------------|
| `yarn_builder.js` | 169 | `eval()` → C2 fetch |
| `webpack_builder.js` | 189 | `eval()` → C2 fetch |
| `babel_config.js` | 204 | `eval()` → C2 fetch |

Detection pattern: `String.fromCharCode(a[i] ^ k)`

### 6. Luraph Lua Payloads

**First documented by JGN — previously unknown infection pathway.**

**Deobfuscated:** [`deobfuscated/luraph_payloads_deobfuscated.js`](deobfuscated/luraph_payloads_deobfuscated.js)

| Endpoint | MD5 | API Key | Fetches From |
|----------|-----|---------|-------------|
| `/test` | `97a72874...` | zXeAH | `9ns1.com/zXeAHJJ` |
| `/dev` | `a6fa269b...` | dev | `fivems.lt/devJJ` |
| `/null` | `01df43ee...` | null | `fivems.lt/nullJJ` |

**How the Lua infection works:**

1. Checks KVP `installed_notices` (first-run flag)
2. Drops polymorphic XOR JS file (random name from: entry.js, init.js, stack.js, runtime.js, interface.js, bridge.js)
3. XOR key: `"r"` + 4 random digits (e.g., r2464, r5246)
4. Modifies `fxmanifest.lua` to load dropper as `server_script`
5. Phones home to Discord webhook with server info
6. On restart → `require('vm').runInThisContext` → C2 fetch → full backdoor

**Discord phone-home webhook** (shared across all 3 payloads):
```
Webhook ID: 1470175544682217685
```

**Self-reported version:** v4.5

---

## Panel Architecture

### Authentication

Discord OAuth2 → fetch `discord.com/api/users/@me` → validate against hardcoded admin whitelist.

**Admin whitelist:** `["393666265253937152", "1368690772123062292"]`

**OAuth App ID:** `1444110004402655403` (name: "blum", `bot_public: true`)

### Admin API

Server-side validated — cannot be bypassed by spoofing headers.

```
GET  /admin/stats              Panel statistics
GET  /admin/users              All customer accounts
GET  /admin/servers?page=&limit=   Infected server list (paginated)
GET  /admin/payloads           All available payloads
GET  /admin/activity           Activity log
POST /admin/users              Create customer
PUT  /admin/users/{api}        Update customer
DELETE /admin/users/{api}      Delete customer
DELETE /admin/servers/{id}     Remove server
```

### Customer Auth

Separate from admin OAuth. Uses `serverId` + 4-character auth code.

### Pricing

| Plan | Price |
|------|-------|
| Basic | EUR 59.99/month |
| Ultima | EUR 139.99 lifetime |

Accepts: Bitcoin, Litecoin, Solana, Amazon gift cards (GBP), MoonPay.

---

## Discord Bot Module

Beyond FiveM server control, the panel includes a Discord bot that can take over victims' Discord servers:

| Category | Commands |
|----------|----------|
| Server | connect, disconnect, getServers |
| Members | getMembers, banMember, kickMember, timeoutMember, changeNickname |
| Channels | getChannels, createChannel, createRole, createInvite |
| Messaging | sendMessage, getWebhooks, createAllWebhooks, sendViaWebhooks |

---

## Attacker Identity and Financial Intelligence

### Blum Panel Operators

| Item | Value |
|------|-------|
| Primary admin Discord | `393666265253937152` (~2018 account) |
| Secondary admin Discord | `1368690772123062292` (~May 2025 account) |
| Discord OAuth App | `1444110004402655403` (name: "blum") |
| App verify key | `a4836c8b69653c856f7108f8f7a63b8f8445698f49b73142a68fb27749dc7cf5` |
| Payment webhook secret | `1221885230680375427` |
| Phone-home webhook | `1470175544682217685` |
| Known handles | bertjj, bertjjgg, miauss, miausas |
| Discord server | `discord.com/invite/VB8mdVjrzd` |

### Cipher Panel Creator

| Item | Value |
|------|-------|
| Creator | **Authentic** / `authentic777` |
| Discord ID | `1072311313080004648` (~May 2022 account) |
| Domain | `cipher-panel.me` |
| Discord server | `discord.gg/ciphercorp` |
| Discord role | "CIPHER CREATOR" + "Moderators" |
| Active since | ~2021 |
| Confirmed Blum is stolen code | February 4, 2026 (public Discord post) |

### Cryptocurrency

**Bitcoin:** `bc1q2wd7y6cp5dukcj3krs8rgpysa9ere0rdre7hhj`
- 9 transactions, ~$2,000 received (Nov 2025 – Feb 2026)

**Litecoin:** `LSxKJm6SpdExCACUcFTUADcvZgea65AaWo`
- 89 transactions, 76.53 LTC received (~$8,000–$10,000)
- 88 incoming payments — estimated 60–90 unique customers

**Solana:** `vDWomGGtBctKqtTkRm6maXc7KJrvtmc2x8WXEzbuzkz`

**Minimum confirmed revenue:** $10,000–$12,000 (crypto only, gift cards untraceable)

### Geographic Indicators

| Evidence | Points To |
|----------|-----------|
| `.lt` domain TLD | Lithuania |
| File server hosting (UAB Esnet, Vilnius) | Lithuania |
| `jking.lt` in C2 domain list | Lithuania |
| EUR pricing | European Union |
| GBP gift cards + moonpay.com/en-gb | UK customer base |

---

## C2 Probe Results

On March 14, 2026, JGN connected a passive Socket.IO probe to `wss://fivems.lt`:

| Result | Details |
|--------|---------|
| Connection | Accepted — registered as fake server "Los Santos Roleplay" |
| Socket ID | Assigned (`7BPfrbSsVWWLD7q2BNDg`) |
| Heartbeat | `heartbeat_ack` received on every 30s beat — C2 alive |
| sendWebhooks | Returned `{"status":"sent"}` with real IP — webhook confirmed live |
| Protocol | 100% correct — all deobfuscated event names verified |
| Panel heartbeat | `{"count":5}` — 4-10 active users during observation |

The probe script is included at [`detection/c2_probe.js`](detection/c2_probe.js).

---

## Detection and Remediation

### Automated Scanner

```bash
# Download and run (13 checks including Luraph detection)
chmod +x detection/scan.sh
cd /path/to/fivem/server
/path/to/detection/scan.sh
```

### Manual Detection

```bash
# JavaScript backdoor patterns
grep -rn "String.fromCharCode(a\[i\]\^k)" --include="*.js"
grep -rn "bertjj\|miauss\|fivems\.lt\|ggWP\|helpEmptyCode\|JohnsUrUncle" --include="*.js" --include="*.lua"
grep -rn "RESOURCE_EXCLUDE" --include="*.lua"

# Lua backdoor patterns (NEW — most scanners miss these)
grep -rn "Luraph Obfuscator\|installed_notices" --include="*.lua"
grep -rn "9ns1\.com\|devJJ\|nullJJ\|zXeAHJJ" --include="*.js" --include="*.lua"

# Discord webhook phone-home
grep -rn "1470175544682217685" --include="*.lua" --include="*.js"
```

### Remediation Checklist

1. Run `detection/scan.sh` from your server root
2. Delete all identified dropper `.js` files (entry.js, init.js, stack.js, runtime.js, interface.js, bridge.js, yarn_builder.js, webpack_builder.js, babel_config.js)
3. Clean every `fxmanifest.lua` — remove any injected `server_scripts` entries
4. Restore txAdmin files from [official GitHub](https://github.com/tabarra/txAdmin):
   - `sv_main.lua`
   - `sv_resources.lua`
   - `cl_playerlist.lua`
5. Run `detection/block_c2.sh` to block all C2 domains at network level
6. Deploy `dropper_trap/` resource for ongoing runtime protection
7. Check txAdmin for any admin account named "JohnsUrUncle" — delete if found
8. Verify `GlobalState.miauss` and `GlobalState.ggWP` are empty
9. **Change all txAdmin passwords and API tokens immediately**
10. Report to contacts listed in [Reporting Contacts](#reporting-contacts)

### Included Tools

| Tool | Description |
|------|-------------|
| [`detection/scan.sh`](detection/scan.sh) | 13-check automated scanner (v4, includes Luraph detection) |
| [`detection/block_c2.sh`](detection/block_c2.sh) | Network blocker using REJECT rules (CDN-safe, includes 9ns1.com) |
| [`detection/c2_probe.js`](detection/c2_probe.js) | Passive Socket.IO probe — register fake server, log all C2 traffic |
| [`dropper_trap/`](dropper_trap/) | FiveM resource — hooks filesystem and network calls at runtime |

---

## Repository Structure

```
blum-panel-analysis/
│
├── README.md                                 You are here
├── BLUM_INVESTIGATION_REPORT.md              Full investigation timeline & methodology
│
├── detection/
│   ├── scan.sh                               13-check malware scanner (v4)
│   ├── block_c2.sh                           C2 blocker (REJECT rules, CDN-safe)
│   └── c2_probe.js                           Socket.IO passive C2 probe
│
├── dropper_trap/
│   ├── fxmanifest.lua                        FiveM manifest
│   ├── trap.lua                              Lua runtime hooks (v3)
│   └── trap.js                               JS runtime hooks (v3, async)
│
├── deobfuscated/
│   ├── c2_payload.js                         Replicator (1.6MB → 37KB)
│   ├── deobfuscated_main.js                  C2 loader (425KB → 14KB)
│   ├── deobfuscated_script.js                Screen capture (183KB → 26KB)
│   ├── deobfuscated_yarn_builder.js          XOR dropper decoded
│   ├── deobfuscated_sv_main.lua              Tampered txAdmin file
│   ├── deobfuscated_sv_resources.lua         RCE backdoor decoded
│   └── luraph_payloads_deobfuscated.js       All 3 Lua payloads decoded
│
└── iocs/
    ├── domains.txt                           27+ C2 and panel domains
    ├── hosts_block.txt                       Drop-in /etc/hosts blocklist
    ├── pihole_block.txt                      Pi-hole compatible blocklist
    ├── pastebin_urls.txt                     Pastebin fallback URLs
    ├── strings.txt                           55+ detection signatures
    ├── socket_io_protocol.md                 Complete C2 protocol specification
    └── attacker_intel.md                     Identity, wallets, infrastructure
```

---

## Reporting Contacts

| Target | Contact | What to Report |
|--------|---------|---------------|
| **Cfx.re** | FiveM Team | This full analysis package |
| **Cloudflare** | abuse@cloudflare.com | fivems.lt, blum-panel.me, warden-panel.me, 9ns1.com |
| **UAB Esnet** | abuse@vpsnet.lt | 185.80.128.35 — stolen file hosting |
| **Discord** | Trust & Safety | Invite VB8mdVjrzd, App 1444110004402655403, Webhook 1470175544682217685, Users 393666265253937152 + 1368690772123062292 + 1072311313080004648 |
| **DOMREG.lt** | .lt registrar | fivems.lt, jking.lt |
| **JScrambler** | Contact form | Commercial obfuscator being used for malware |
| **Luraph** | Contact form | Commercial obfuscator being used for malware |
| **Law Enforcement** | IC3.gov / local cyber unit | Crypto wallets for financial tracing |

---

## Investigation Statistics

| Metric | Value |
|--------|-------|
| Total investigation time | ~16 hours |
| Malware files analyzed | 11 + 1 panel bundle |
| Obfuscated code processed | ~3.7 MB |
| Deobfuscated output | ~140 KB |
| Obfuscation layers cracked | 5 (JS) + Luraph VM (Lua) + XOR |
| Base-91 strings decoded | 40,000+ |
| Generator state machines flattened | 215 |
| C2 domains identified | 27+ |
| Socket.IO commands documented | 75 |
| Crypto transactions analyzed | 98 |
| Estimated attacker revenue | $10,000 – $12,000+ |
| Estimated customers | 60 – 90 |
| Detection signatures | 55+ |
| Active panel users observed | 4 – 10 |
| Operation age | ~5 years (Cipher origin: 2021) |

---

<p align="center">
  <strong>Research by Justice Gaming Network (JGN)</strong><br>
  <a href="https://discord.gg/JRP">discord.gg/JRP</a><br><br>
  Analysis conducted March 13–14, 2026.<br>
  C2 infrastructure remains active as of publication.
</p>
