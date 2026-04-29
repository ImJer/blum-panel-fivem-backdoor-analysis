<p align="center">
  <h1 align="center">Blum Panel Backdoor</h1>
  <h3 align="center">Complete Deobfuscation, C2 Infiltration & Threat Analysis</h3>
  <p align="center">
    The first public full reverse-engineering of the Blum Panel / Warden Panel FiveM backdoor.<br>
    3,856 infected servers exposed. 1,859 players at risk. 28 paying customers identified.<br>
    C2 infiltrated — full server database, player PII, and attack payload library extracted.
  </p>
  <p align="center">
    <strong>Research by Justice Gaming Network (JGN)</strong><br>
    FiveM Server: <strong>JusticeRP</strong> &mdash; <a href="https://discord.gg/JRP">discord.gg/JRP</a>
  </p>
</p>

---

> **Every obfuscation layer cracked. C2 infiltrated without authentication. Full database extracted.**
> This repository contains deobfuscated source code, the complete infected server database (sanitized),
> the attacker's payload library, detection tools, and a live investigation dashboard.
> 16-hour investigation conducted March 13-14, 2026.

---

## Quick Start — Is My Server Infected?

**Run the scanner** from your FiveM server root:

```bash
chmod +x scan.sh && ./scan.sh
```

**Check for active infection** in your FiveM server console:

```lua
if GlobalState.miauss then print("DROPPER ACTIVE: "..GlobalState.miauss) end
if GlobalState.ggWP then print("REPLICATOR ACTIVE: "..GlobalState.ggWP) end
```

**Search the infected server database** — check if your server name appears in `evidence/infected_servers_sanitized.json`.

**Block the C2 immediately:**

```bash
chmod +x block_c2.sh && ./block_c2.sh
```

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Key Numbers](#key-numbers)
- [Research Attribution](#research-attribution)
- [The Cipher Panel Connection](#the-cipher-panel-connection)
- [The Complete Kill Chain](#the-complete-kill-chain)
- [C2 Infiltration Results](#c2-infiltration-results)
- [Infected Server Database](#infected-server-database)
- [Attack Payload Library](#attack-payload-library)
- [Player Data Exposure](#player-data-exposure)
- [Files Analyzed](#files-analyzed)
- [Obfuscation Architecture](#obfuscation-architecture)
- [C2 Infrastructure](#c2-infrastructure)
- [Malware Components](#malware-components)
- [GFX Panel — Second Product](#gfx-panel--second-product)
- [Panel Architecture](#panel-architecture)
- [Attacker Identity and Financial Intelligence](#attacker-identity-and-financial-intelligence)
- [Detection and Remediation](#detection-and-remediation)
- [Repository Structure](#repository-structure)
- [Reporting Contacts](#reporting-contacts)

---

## Executive Summary

Blum Panel is a commercial FiveM backdoor sold for EUR 59.99/month or EUR 139.99 lifetime. It gives paying customers full remote control over infected FiveM servers — code execution, live screen capture, player manipulation, economy exploitation, full filesystem access, and complete server lockdown.

By registering a fake server on the C2, JGN extracted the **complete infected server database** (3,856 servers), **player PII** (289 players with real IP addresses, Discord IDs, and Steam identifiers), and the **full attack payload library** (7 pre-built RCE scripts) — all without any authentication.

The investigation also revealed that Blum Panel is built on **stolen Cipher Panel code**, confirmed by Cipher's creator. The attacker operates a second product called **GFX Panel** on unprotected infrastructure. The **origin C2 server** was identified at `185.87.23.198` (active 1 GmbH, Hamburg, Germany). Five panel domains, four direct IP servers, and 28 paying customers were identified across a 16-hour investigation. The C2 generates payloads for **any API key dynamically** — it is not access-controlled.

---

## Key Numbers

| Metric | Value |
|--------|-------|
| **Infected servers in database** | **3,856** |
| **Players at risk at time of capture** | **1,859** |
| **Total server capacity** | **350,933 player slots** |
| **Servers with active players** | **584** |
| **Personal PCs compromised** | **392** |
| **Paying customers identified** | **28 unique API keys** |
| **Longest active infection** | **2,582 hours (107 days)** |
| **Countries affected** | **15+** (FR, US, SA, BR, TR, DE, RO, PL, CN, IT, ES, NL, IL...) |
| **Pre-built attack payloads** | **7** (txAdmin bypass, kickall, server takeover, admin backdoor) |
| **Player PII exposed per session** | **~1,500-2,000** with real IPs, Discord IDs, Steam IDs |
| **Cryptocurrency revenue** | **$10,000-$12,000+** confirmed |
| **Panel domains** | **5** (blum-panel.me, warden-panel.me, 9ns1.com, fivems.lt, jking.lt) |
| **Origin server** | **185.87.23.198** (active 1 GmbH, Hamburg, Germany, port 5000) |
| **C2 status** | **9ns1.com active** — fivems.lt dying (some endpoints return 12 bytes) |
| **Authentication required for data access** | **None** |
| **API key access control** | **None** — server generates payloads for ANY key dynamically |

---

## Research Attribution

This research was conducted by the **Justice Gaming Network (JGN)** team, operators of the **JusticeRP** FiveM server.

**Discord:** [discord.gg/JRP](https://discord.gg/JRP)

**Firsts accomplished by JGN:**

- First public deobfuscation of any Blum Panel or Cipher Panel file
- First C2 infiltration — extracted complete server database of 3,856 infected servers
- First extraction of the attack payload library (7 pre-built RCE scripts)
- First documentation of player PII exposure (real IPs, Discord IDs, Steam IDs)
- First identification of the Lua infection pathway (Luraph payloads)
- First discovery of the second C2 domain (9ns1.com)
- First discovery of GFX Panel — second product by the same attacker
- First proof that Cipher Panel code was stolen by Blum Panel
- First complete Socket.IO protocol documentation (75 commands)
- First identification of txAdmin credential theft and WebRTC screen capture
- First extraction of attacker Discord IDs, crypto wallets, and OAuth app
- First identification of origin C2 server IP (185.87.23.198, Hamburg, Germany)

---

## The Cipher Panel Connection

On **February 4, 2026**, the Cipher Panel creator **Authentic** (`authentic777`, Discord ID `1072311313080004648`) posted publicly:

> *"Let's give a round of applause to Blum-panel, aka Cipher copy-pasta, for this incredible update!
> Those who thought they were above Cipher now find themselves at their rightful level.
> Stop buying copy-pasta panels; you're better off sticking with Cipher. CIPHER > ALL"*

Authentic holds the **CIPHER CREATOR** role in the Cipher Discord and has `cipher-panel.me` on their profile.

**Blum Panel stole Cipher Panel's codebase.** The Blum frontend bundle contains hardcoded references to `cipher-panel.me` and `discord.gg/ciphercorp` — leftover artifacts from the stolen code. The backends are different (Cipher uses nginx, Blum uses Express.js), confirming different operators running the same codebase. Both are active criminal operations.

---

## The Complete Kill Chain

```
 INITIAL INFECTION (Two paths)

  PATH A: JavaScript (yarn_builder.js, webpack_builder.js, etc.)
  XOR-encrypted eval -> fetches C2 loader (main.js, 425KB)
  main.js -> setImmediate dropper -> fetches replicator from C2

  PATH B: Lua (Luraph-obfuscated, 65KB)
  Drops XOR-encrypted JS file + modifies fxmanifest.lua
  Sends Discord webhook to attacker (infection notification)
  On restart -> JS dropper -> fetches replicator from C2

 STAGE 2: REPLICATOR (c2_payload.txt, 1.6MB, memory only)

  T+2s   Collect server info (framework, anticheats, license)
  T+3s   Infect server (4 components):
         XOR dropper injection into 40+ resource files
         server.cfg injection at random position
         txAdmin sv_main.lua tampering (hide from dashboard)
         txAdmin credential theft (X-TxAdmin-Token capture)
  T+32s  Connect to C2 via Socket.IO (wss://fivems.lt)

 STAGE 3: PERSISTENT BACKDOOR (Socket.IO, 39 event handlers)

  Arbitrary JS/Lua code execution
  WebRTC live screen capture of any player
  Player manipulation (kill, ban, godmode, spawn vehicles)
  Economy manipulation (add/remove items, set jobs)
  Full filesystem access (read, write, delete, browse)
  Resource theft (ZIP + upload to attacker server)
  Console capture (last 500 lines)
  Server lockdown (kick all + block connections)
  txAdmin admin creation ("JohnsUrUncle", all_permissions)
  Discord bot control (24 commands)
```

---

## C2 Infiltration Results

JGN registered a fake server on the Blum Panel C2 and extracted the entire database without authentication.

The C2 server accepts any Socket.IO connection that emits `registerServer` with a valid API key format. Once registered, emitting server list events returns the complete database of every infected server. No admin credentials needed.

### What We Extracted

| Data | Method | Authentication |
|------|--------|---------------|
| 3,856 infected servers | `registerServer` + list events | **None** |
| 289 player records with real IPs | `getServerPlayers` per server | **None** |
| 7 attack payloads with full source | `getPayloads` with serverId | **None** |
| Per-server info on demand | `getServerInfo` with serverId | **None** |
| Discord member queries | `discord:members` with serverId | **None** |

### What Was Protected

| Data | Status |
|------|--------|
| Admin panel (user management) | Requires Discord OAuth |
| Console output from servers | No response |
| File browser | No response |
| Resource lists | No response |
| Command execution | Requires customer session |

---

## Infected Server Database

**File:** `evidence/infected_servers_sanitized.json`

Captured March 14, 2026 at 08:19 UTC. Contains server names and metadata for every server that has connected to the Blum Panel C2. Victim IP addresses, licenses, and identifiers have been redacted from the public release.

### By Customer (API Key)

| API Key | Servers | Description |
|---------|---------|-------------|
| zXeAHJJ | 2,765 | Largest customer or default key |
| nullJJ | 442 | Second largest |
| bekJJ | 178 | |
| bertJJ | 117 | Original attacker handle |
| xxx | 103 | |
| qwertyJJ | 103 | |
| dovJJ | 55 | |
| + 21 others | 93 | Smaller customers |

### By Framework

| Framework | Count |
|-----------|-------|
| ESX | 1,836 (48%) |
| QBCore | 1,373 (36%) |
| vRP | 355 (9%) |
| Unknown | 291 (7%) |

### By Operating System

| OS | Count |
|----|-------|
| Windows | 2,502 (65%) |
| Linux | 1,353 (35%) |

### Top Countries (by locale)

| Locale | Servers |
|--------|---------|
| Unidentified (root-AQ) | 692 |
| France (fr-FR) | 389 |
| United States (en-US) | 389 |
| Saudi Arabia (ar-SA) | 312 |
| Brazil (pt-BR) | 232 |
| Turkey (tr-TR) | 159 |
| Germany (de-DE) | 130 |
| Romania (ro-RO) | 87 |
| Poland (pl-PL) | 83 |
| China (zh-CN) | 80 |

### Top Servers by Player Count (at capture)

| Players | Server Name | Customer |
|---------|------------|----------|
| 83/250 | ZONASUR-RP | dovJJ |
| 73/200 | Traplanta V3 | zXeAHJJ |
| 64/128 | Respect CFW | zXeAHJJ |
| 48/180 | Lost In Thought 2.0 | zXeAHJJ |
| 46/965 | MOSCOW RP S4 | zXeAHJJ |
| 39/128 | NOVA CITY | zXeAHJJ |
| 33/180 | BANEADOS RP | zXeAHJJ |
| 31/128 | Capital Legacy | zXeAHJJ |
| 29/500 | VIPURI ROMANIA ROLEPLAY | zXeAHJJ |
| 25/64 | Sinaloa 701 RP | zXeAHJJ |

### Longest Infections

| Uptime | Server Name | Customer |
|--------|------------|----------|
| 2,582 hours (107 days) | District 18 Roleplay [Israel] | zXeAHjj |
| 2,559 hours (106 days) | TRILL LIFE RP | zXeAHjj |
| 2,238 hours (93 days) | Young and Rich Development | zXeAHjj |
| 2,227 hours (92 days) | Solaria FA | zXeAHjj |
| 2,193 hours (91 days) | UnderworldTest dev server | xxx |

---

## Attack Payload Library

**File:** `evidence/BLUM_PAYLOADS.json` (23 KB)

Seven pre-built attack scripts available to all customers via one-click deployment. Full source code captured.

| ID | Name | Language | Created | Purpose |
|----|------|----------|---------|---------|
| 2 | ENABLE TXADMIN BYPASS | Lua | Nov 24, 2024 | Disables txAdmin player join verification |
| 5 | DISABLE TXADMIN BYPASS | Lua | Nov 24, 2024 | Re-enables (stealth toggle) |
| 30 | /kickall | Lua | Dec 7, 2024 | Kicks all players with "[warden-panel.me/discord]" message |
| 38 | Spektaklis NEW | Lua | Dec 14, 2024 | Rainbow spam + music + visual takeover with branding |
| 56 | /miaumiau admin | Lua | Dec 22, 2024 | Backdoor command to get ESX admin privileges |
| 62 | russian heck | Lua | Dec 22, 2024 | DUI-based visual attack |
| 79 | txAdmin crash | JS | Jan 17, 2025 | Crashes txAdmin by binding to its port, blocking admin access |

All payloads use `api: "every"` meaning they are available to every customer, not restricted by API key. The earliest payload dates to **November 2024**, proving the operation has been actively maintained for over a year.

---

## Player Data Exposure

The Blum Panel C2 exposes the following data for every connected player, accessible without any authentication:

- **Real IP address** (home IP, not proxy)
- **Player name**
- **Discord ID**
- **Steam or License identifier**
- **Server they are connected to**

At time of capture: **289 unique players** from **35 servers** with **289 real IPs** and **286 Discord IDs** exposed. With 1,859 players online across 584 active servers, the total exposure at any given time is approximately **1,500-2,000 players**.

Player PII has been fully redacted from the public release. Statistics are in `evidence/player_pii_stats.json`.

---

## Files Analyzed

| File | Size | Obfuscator | Purpose |
|------|------|------------|---------|
| main.js | 425 KB | JScrambler | C2 loader |
| script.js | 183 KB | JScrambler | WebRTC screen capture |
| c2_payload.txt | 1.64 MB | JScrambler | Live replicator (core backdoor) |
| ext/bert | 425 KB | JScrambler | Dropper from C2 |
| yarn_builder.js | 43 KB | XOR (key 169) | Dropper in yarn resource |
| webpack_builder.js | 632 KB | XOR (key 189) | Dropper in webpack resource |
| babel_config.js | 20 KB | XOR (key 204) | Dropper in babel resource |
| sv_main.lua | 18 KB | Tampered | txAdmin cloaking |
| sv_resources.lua | 2 KB | Tampered | txAdmin RCE backdoor |
| /test | 65 KB | Luraph v14.6 | Lua dropper to 9ns1.com |
| /dev | 64 KB | Luraph v14.6 | Lua dropper to fivems.lt |
| /null | 64 KB | Luraph v14.6 | Lua dropper to fivems.lt |
| Panel bundle | 1.97 MB | Minified React | Customer dashboard |
| GFX bundle | 749 KB | Minified React | Second product dashboard |

---

## Obfuscation Architecture

### JavaScript — JScrambler (5 Layers)

Commercial obfuscator (~$100/month). Function() wrapper, LZString compression, Base-91 encoding (122 alphabets, 40,000+ strings), indirection arrays (up to 3,014 elements), generator state machines (215 total). Bloat ratio ~200:1.

### Lua — Luraph v14.6

Commercial obfuscator (~$20/month). Custom bytecode VM with 140+ opcodes, pcall-wrapped execution, embedded compressed bytecode. Three unique builds.

### XOR Droppers

`String.fromCharCode(a[i] ^ k)` with keys 169, 189, 204. Decrypts to eval() fetching from C2.

---

## C2 Infrastructure

### Infrastructure Diagram

```
                         ATTACKER INFRASTRUCTURE
    ================================================================

    BLUM PANEL — Primary Operation (stolen Cipher Panel code)
    ─────────────────────────────────────────────────────────
    
    Cloudflare Account #1 (nameservers: bailey/ezra)
    ┌─────────────────────────────────────────────────────┐
    │  9ns1.com          ──┐                              │
    │  fivems.lt         ──┼── ONE Express.js backend     │
    │  warden-panel.me   ──┘   heartbeat: {"count":4}     │
    │                                                     │
    │  jking.lt          ──── SEPARATE Express.js backend │
    │                          heartbeat: {"count":2}     │
    └─────────────────────────────────────────────────────┘

    Cloudflare Account #2 (nameservers: keenan/paityn)
    ┌─────────────────────────────────────────────────────┐
    │  blum-panel.me     ──── SAME backend as above       │
    │                          heartbeat: {"count":4}     │
    └─────────────────────────────────────────────────────┘

    Evidence: All four domains (blum, warden, 9ns1, fivems) return
    identical heartbeat count = single Express.js origin server.
    blum-panel.me is on a separate Cloudflare account from the others.

    ORIGIN SERVER — The real backend behind Cloudflare
    ──────────────────────────────────────────────────
    ┌─────────────────────────────────────────────────────┐
    │  185.87.23.198     ── Express.js on port 5000       │
    │                       active 1 GmbH                 │
    │                       Hamburg, Germany               │
    │                       ASN: AS197071                  │
    │                       ALL panel domains proxy here   │
    │                                                     │
    │  NOTE: fivems.lt is DYING (some endpoints return    │
    │  12 bytes). 9ns1.com is the active primary C2.      │
    │                                                     │
    │  API keys are NOT access-controlled — the server    │
    │  generates valid payloads for ANY key dynamically.   │
    └─────────────────────────────────────────────────────┘

    BACKUP C2 DOMAINS (payload delivery only, no panel)
    ┌─────────────────────────────────────────────────────┐
    │  2ns3.net          ── AWS 13.248.213.45 (active)    │
    │  giithub.net       ── Cloudflare (522 error)        │
    │  + 20 more fallback domains hardcoded in replicator │
    └─────────────────────────────────────────────────────┘

    GFX PANEL — Second Product (built with GPT Engineer)
    ─────────────────────────────────────────────────────
    ┌─────────────────────────────────────────────────────┐
    │  gfxpanel.org      ──┐                              │
    │  kutingplays.com   ──┴── 185.80.130.168 (DIRECT)    │
    │                          NO CLOUDFLARE              │
    │                          Port 3000 open (raw API)   │
    │                          Port 22 open (SSH)         │
    │                          Apache/2.4.52 + Express.js │
    │                          Ubuntu, Let's Encrypt SSL  │
    └─────────────────────────────────────────────────────┘

    DIRECT IP SERVERS — UAB Esnet, Vilnius, Lithuania
    ─────────────────────────────────────────────────
    ┌─────────────────────────────────────────────────────┐
    │  185.80.128.35     ── Apache/2.4.29, Ubuntu 18.04   │
    │                       Stolen FiveM resource hosting  │
    │                       Paths: /download-resource/     │
    │                                                     │
    │  185.80.128.36     ── Apache/2.4.65, Debian         │
    │                       Default page (staging/spare)   │
    │                                                     │
    │  185.80.130.168    ── GFX Panel (see above)         │
    │                       Also responds to Socket.IO    │
    │                       for ALL Host headers           │
    │                                                     │
    │  Abuse: abuse@vpsnet.lt                             │
    │  Network: VPSNET-COM, Zuvedru g. 36, Vilnius        │
    └─────────────────────────────────────────────────────┘

    CIPHER PANEL — Original Operation (code stolen by Blum)
    ────────────────────────────────────────────────────────
    ┌─────────────────────────────────────────────────────┐
    │  cipher-panel.me   ── nginx/1.18.0 via Cloudflare   │
    │                       DIFFERENT backend from Blum   │
    │                       NO payload endpoints (all 404)│
    │                       Separate operation entirely    │
    └─────────────────────────────────────────────────────┘
```

### Single Backend Discovery

All panel domains return identical heartbeat counts, confirming one Express.js server behind multiple Cloudflare domains:

```
blum-panel.me/heartbeat    -> {"count":4}
warden-panel.me/heartbeat  -> {"count":4}
9ns1.com/heartbeat          -> {"count":4}    (same backend)
fivems.lt/heartbeat         -> (same backend)
jking.lt/heartbeat          -> {"count":2}    (separate instance)
```

### Cloudflare Account Analysis

Two separate Cloudflare accounts manage the domains:

| Nameservers | Domains | Implication |
|-------------|---------|-------------|
| bailey.ns.cloudflare.com / ezra.ns.cloudflare.com | 9ns1.com, fivems.lt, warden-panel.me, jking.lt | Primary Cloudflare account |
| keenan.ns.cloudflare.com / paityn.ns.cloudflare.com | blum-panel.me | Separate Cloudflare account |

This may indicate blum-panel.me was set up at a different time or by a different team member.

### SSL Certificate History (Origin Exposure)

Certificate Transparency logs reveal **Let's Encrypt certificates** issued before Cloudflare was added, meaning the origin server IP was briefly exposed:

| Domain | Let's Encrypt Cert | Date | Implication |
|--------|-------------------|------|-------------|
| blum-panel.me | Let's Encrypt E8 | Jan 31, 2026 | Origin IP was visible |
| blum-panel.me | Let's Encrypt E8 | Dec 3, 2025 | Origin IP was visible |
| fivems.lt | Let's Encrypt E7 | Dec 10, 2025 | Origin IP was visible |
| fivems.lt | Let's Encrypt E7 | Oct 12, 2025 | Origin IP was visible |
| fivems.lt | Let's Encrypt E7 | Aug 7, 2025 | Origin IP was visible |

Historical DNS databases queried during these windows may reveal the true origin IP behind Cloudflare.

### Complete Domain Map

| Domain | Type | Backend | IP/Proxy | Registrar | Created |
|--------|------|---------|----------|-----------|---------|
| blum-panel.me | Panel + C2 | Express.js | Cloudflare | Namecheap | ~Dec 2025 |
| warden-panel.me | Panel + C2 | Express.js | Cloudflare | Namecheap | ~Jan 2026 |
| 9ns1.com | Panel + C2 | Express.js | Cloudflare | Namecheap | Jun 29, 2025 |
| fivems.lt | Panel + C2 | Express.js | Cloudflare | DOMREG.lt | ~Aug 2025 |
| jking.lt | Panel + C2 (separate) | Express.js | Cloudflare | DOMREG.lt | Unknown |
| gfxpanel.org | GFX Panel | Express.js | 185.80.130.168 DIRECT | Namecheap | Feb 7, 2026 |
| kutingplays.com | GFX Panel alias | Express.js | 185.80.130.168 DIRECT | Unknown | Unknown |
| cipher-panel.me | Original panel | nginx | Cloudflare | Unknown | ~2021 |
| 2ns3.net | Backup C2 | Unknown | 13.248.213.45 (AWS) | Unknown | Unknown |
| giithub.net | Backup C2 (dead) | Unknown | Cloudflare (522) | Unknown | Unknown |

All Blum panel domains serve identical React bundle: `index-BmknYBUo.js` (1,972,893 bytes).
GFX Panel serves a different bundle: `index-B62S1OtC.js` (749,436 bytes).

### Direct IP Servers

Three servers at UAB Esnet (VPSNET-COM) in Vilnius, Lithuania:

| IP | Server | Service | Purpose |
|----|--------|---------|---------|
| 185.80.128.35 | Apache/2.4.29 (Ubuntu 18.04) | HTTP only | Stolen FiveM resource file hosting |
| 185.80.128.36 | Apache/2.4.65 (Debian) | HTTP only | Default page (staging or spare) |
| 185.80.130.168 | Apache/2.4.52 + Express.js (Ubuntu) | HTTP, HTTPS, SSH, Port 3000 | GFX Panel, Socket.IO C2, raw API |

All three share the same hosting provider, abuse contact (abuse@vpsnet.lt), and are in the same Vilnius datacenter. The 185.80.130.168 server also responds to Socket.IO connections with any Host header, suggesting it may proxy or have previously hosted additional services.

### Payload Delivery Infrastructure

Every C2 domain serves all four payload variants. Each payload is identical JScrambler-obfuscated code (~1.64 MB) with only two plaintext header variables changed:

```javascript
ende = "devJJ";                // endpoint identifier
back = "https://fivems.lt";    // C2 callback URL
Function("bHl1Cq",...          // JScrambler blob (identical)
```

| Endpoint | API Key | Payload Size | Served From |
|----------|---------|-------------|-------------|
| /bertJJ | bert | 1,643,855 bytes | fivems.lt, 9ns1.com, jking.lt, warden-panel.me |
| /bertJJgg | bert | 1,643,855 bytes | fivems.lt (fallback) |
| /bertJJcfxre | bert | 1,643,855 bytes | fivems.lt (fallback) |
| /devJJ | dev | 1,643,854 bytes | fivems.lt, 9ns1.com, jking.lt, warden-panel.me |
| /nullJJ | null | 1,643,855 bytes | fivems.lt, 9ns1.com, jking.lt, warden-panel.me |
| /zXeAHJJ | zXeAH | 1,643,855 bytes | fivems.lt, 9ns1.com, jking.lt, warden-panel.me |
| /ext/bert | bert (dropper) | 425,385 bytes | fivems.lt, 9ns1.com |
| /test | Lua dropper | 65,564 bytes | fivems.lt, 9ns1.com |
| /dev | Lua dropper | 64,115 bytes | fivems.lt, 9ns1.com |
| /null | Lua dropper | 64,289 bytes | fivems.lt, 9ns1.com |

The Lua endpoints (/test, /dev, /null) serve Luraph v14.6 obfuscated payloads that drop XOR-encrypted JS files — the initial infection vector for the Lua pathway.

23+ additional fallback domains are hardcoded in the replicator for resilience. Full list in `iocs/domains.txt`.

### Socket.IO Protocol — 75 Commands

Full specification: `iocs/socket_io_protocol.md`

1 arbitrary code execution, 5 screen capture, 10 player manipulation, 5 economy, 11 filesystem, 3 server admin, 1 txAdmin theft, 24 Discord bot, 13 telemetry, 1 heartbeat.

---

## Malware Components

See `deobfuscated/` directory for full deobfuscated source:

- **c2_payload.js** — Core replicator (1.64 MB to 37 KB, 15 sections)
- **deobfuscated_main.js** — C2 loader (425 KB to 14 KB)
- **deobfuscated_script.js** — Screen capture (183 KB to 26 KB)
- **luraph_payloads_deobfuscated.js** — All 3 Lua payloads decoded
- **deobfuscated_yarn_builder.js** — XOR dropper
- **deobfuscated_sv_main.lua** — Tampered txAdmin (RESOURCE_EXCLUDE)
- **deobfuscated_sv_resources.lua** — txAdmin RCE backdoor

---

## GFX Panel — Second Product

The attacker operates a second panel called GFX Panel on unprotected infrastructure:

| Item | Value |
|------|-------|
| Domains | gfxpanel.org, kutingplays.com |
| Backend | Express.js + Apache/2.4.52 on Ubuntu, direct IP, no Cloudflare |
| Bundle | index-B62S1OtC.js (749 KB, 38% of Blum) |
| Built with | GPT Engineer (project: eSi92A9tMBTQWYu6OPvMFhyFiy72) |
| Discord | discord.gg/cwd5kHwq6v (dead) |
| Port 3000 | Open — raw Express.js exposed |
| Socket.IO | Live |
| Created | February 7, 2026 (Namecheap) |

GFX Panel serves Luraph-obfuscated Lua payloads from non-standard endpoints (/heartbeat, /register, /sendWebhooks). Hosted at UAB Esnet datacenter in Vilnius, Lithuania — same provider as the file hosting servers.

---

## Panel Architecture

**Authentication:** Discord OAuth2 with hardcoded admin whitelist.

**Admin Discord IDs:** `393666265253937152`, `1368690772123062292`

**OAuth App:** `1444110004402655403` (name: "blum")

**Pricing:** Basic EUR 59.99/month, Ultima EUR 139.99 lifetime.

**Payment:** Bitcoin, Litecoin, Solana, Amazon gift cards (GBP), MoonPay.

**Discord Bot:** 24 commands including ban, kick, timeout, create channels/roles, send messages via webhooks. Can take over victims' Discord servers.

---

## Attacker Identity and Financial Intelligence

### Blum Panel Operators

| Item | Value |
|------|-------|
| Primary admin | Discord ID 393666265253937152 (~2018 account) |
| Secondary admin | Discord ID 1368690772123062292 (~May 2025) |
| OAuth App | 1444110004402655403 (name: "blum") |
| Payment webhook | 1221885230680375427 |
| Handles | bertjj, bertjjgg, miauss, miausas |
| Discord | discord.com/invite/VB8mdVjrzd |

### Cipher Panel Creator

| Item | Value |
|------|-------|
| Creator | Authentic / authentic777 |
| Discord ID | 1072311313080004648 (~May 2022) |
| Domain | cipher-panel.me |
| Discord | discord.gg/ciphercorp |
| Confirmed code theft | February 4, 2026 |

### Cryptocurrency

**Bitcoin:** `bc1q2wd7y6cp5dukcj3krs8rgpysa9ere0rdre7hhj` — 9 TX, ~$2,000

**Litecoin:** `LSxKJm6SpdExCACUcFTUADcvZgea65AaWo` — 89 TX, 76.53 LTC (~$8,000-$10,000)

**Solana:** `vDWomGGtBctKqtTkRm6maXc7KJrvtmc2x8WXEzbuzkz`

**Minimum confirmed revenue:** $10,000-$12,000 (crypto only)

### Geographic Indicators

.lt domain TLD, UAB Esnet hosting in Vilnius Lithuania, EUR pricing, GBP gift cards indicating UK customer base.

---

## Detection and Remediation

### Automated Scanner

**Linux:**

```bash
chmod +x detection/scan.sh
cd /path/to/fivem/server
/path/to/detection/scan.sh
```

**Windows Server 2019 / Windows PowerShell 5.1:**

Run the scanner from an elevated or normal PowerShell window. The scanner is read-only: it does not delete files, edit `hosts`, or change firewall rules.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\scan_windows.ps1 -Path C:\FXServer\server-data
```

Optional JSON output for ticketing or archival:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\scan_windows.ps1 -Path C:\FXServer\server-data -Json
```

Exit codes:

| Code | Meaning |
|------|---------|
| `0` | No known indicators found |
| `1` | Only medium/low-confidence findings found |
| `2` | High-confidence indicators found; treat the server as compromised |
| `3` | Invalid scan path or required privilege problem |

### Windows Remediation

`detection/remediate_windows.ps1` is a Windows Server 2019-compatible remediation helper. It runs in dry-run mode by default and does not change files unless `-Apply` is provided.

Recommended order:

1. Stop the FiveM server process
2. Run the remediation script without `-Apply` and review the plan
3. Run it again with `-Apply` only if the planned actions are correct
4. Run `scan_windows.ps1` again after remediation
5. Rotate txAdmin, RCON, database, SSH/RDP, FTP/SFTP, and Discord bot credentials

Preview remediation actions:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\remediate_windows.ps1 -Path C:\FXServer\server-data
```

Apply remediation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\remediate_windows.ps1 -Path C:\FXServer\server-data -Apply
```

Apply remediation and also run the Windows C2 blocker:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\remediate_windows.ps1 -Path C:\FXServer\server-data -Apply -BlockC2
ipconfig /flushdns
```

Restore txAdmin monitor files from official GitHub raw URLs:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\remediate_windows.ps1 -Path C:\FXServer\server-data -Apply -RestoreTxAdminOfficial
```

The remediation script quarantines high- and medium-confidence malicious or suspicious JS/Lua files into a timestamped `_blum_quarantine_*` directory, backs up edited files, removes manifest references to quarantined files, and removes known `helpEmptyCode` / `onServerResourceFail` txAdmin event backdoor blocks. Medium-confidence remediation includes known dropper filenames in suspicious paths and JS/Lua files with known Blum obfuscation or loader markers. It does not permanently delete files and does not automatically edit txAdmin admin JSON files; if it reports `JohnsUrUncle`, remove that admin account manually after backing up txAdmin data.

### Windows C2 Blocking

`detection/block_c2_windows.ps1` is a Windows Server 2019-compatible helper for blocking known Blum/Warden/GFX C2 infrastructure. It runs in dry-run mode by default.

Preview the changes:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\block_c2_windows.ps1
```

Apply protection from an Administrator PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\block_c2_windows.ps1 -Apply
ipconfig /flushdns
```

The `-Apply` mode backs up `C:\Windows\System32\drivers\etc\hosts`, adds `0.0.0.0` entries for known C2 domains, and creates outbound Windows Defender Firewall block rules for direct attacker IPs. It does not block FiveM player-facing ports.

Remove the firewall rules created by the script:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\detection\block_c2_windows.ps1 -Undo
```

The `-Undo` mode removes only the firewall rules created by this script. Hosts entries are left in place; restore the timestamped hosts backup manually if required.

### Manual Detection

```bash
grep -rn "String.fromCharCode(a\[i\]\^k)" --include="*.js"
grep -rn "bertjj\|miauss\|fivems\.lt\|ggWP\|helpEmptyCode\|JohnsUrUncle" --include="*.js" --include="*.lua"
grep -rn "Luraph Obfuscator\|installed_notices" --include="*.lua"
grep -rn "9ns1\.com\|devJJ\|nullJJ\|zXeAHJJ" --include="*.js" --include="*.lua"
```

### Remediation Checklist

1. Run `detection/scan.sh` on Linux or `detection/scan_windows.ps1` on Windows from the server root
2. Delete all dropper .js files
3. Clean fxmanifest.lua files — remove injected server_scripts entries
4. Restore txAdmin files from [official GitHub](https://github.com/tabarra/txAdmin)
5. Run `detection/block_c2.sh` on Linux or `detection/block_c2_windows.ps1 -Apply` on Windows to block known C2 infrastructure
6. Deploy `dropper_trap/` resource for runtime protection
7. Check txAdmin for "JohnsUrUncle" admin account
8. Verify GlobalState.miauss and GlobalState.ggWP are empty
9. Change all txAdmin passwords and API tokens

### Included Tools

| Tool | Description |
|------|-------------|
| `detection/scan.sh` | 13-check scanner (v4, includes Luraph) |
| `detection/block_c2.sh` | Network blocker (REJECT rules, CDN-safe) |
| `detection/scan_windows.ps1` | Windows Server 2019-compatible read-only scanner |
| `detection/block_c2_windows.ps1` | Windows hosts and Defender Firewall C2 blocker |
| `detection/remediate_windows.ps1` | Windows quarantine and cleanup helper |
| `detection/c2_probe.js` | Socket.IO passive C2 probe |
| `dropper_trap/` | FiveM runtime protection hooks |
| `evidence/panel_viewer.html` | Live investigation dashboard |

---

## Repository Structure

```
blum-panel-fivem-backdoor-analysis/
|
+-- README.md                                        This file
+-- BLUM_INVESTIGATION_REPORT.md                     Investigation timeline (16 hours)
+-- GFX_PANEL_ANALYSIS.md                            GFX Panel second product analysis
+-- LICENSE                                          MIT License
|
+-- evidence/
|   +-- infected_servers_sanitized.json              3,856 servers (IPs redacted)
|   +-- BLUM_PAYLOADS.json                           7 attack payloads, full source
|   +-- server_statistics.json                       Statistical breakdown
|   +-- player_pii_stats.json                        Player exposure stats (PII redacted)
|   +-- panel_viewer.html                            Live investigation dashboard
|   +-- gfx_panel.html                               GFX Panel HTML capture
|   +-- decoded_strings_10318.json                   ALL 10,318 decoded obfuscator strings
|   +-- uarzt6_array_3014.json                       Complete 3,014-element indirection array
|   +-- GFX_PANEL_100PCT_DEOBFUSCATED.js             GFX Panel complete analysis
|   +-- gfx_heartbeat_xor_decoded.bin                GFX /heartbeat payload (XOR decoded)
|   +-- gfx_register_xor_decoded.bin                 GFX /register payload (XOR decoded)
|   +-- gfx_test_xor_decoded.bin                     GFX /test payload (XOR decoded)
|
+-- detection/
|   +-- scan.sh                                      13-check malware scanner (v4)
|   +-- block_c2.sh                                  C2 blocker v4 (origin IP + all domains)
|   +-- scan_windows.ps1                             Windows Server 2019 scanner
|   +-- block_c2_windows.ps1                         Windows hosts + firewall C2 blocker
|   +-- remediate_windows.ps1                        Windows quarantine + cleanup helper
|   +-- c2_probe.js                                  Socket.IO C2 probe (targets 9ns1.com)
|   +-- enumerate_servers.sh                         Server enumeration tool
|   +-- blum_probe_v2.sh                             Infrastructure recon v2
|   +-- blum_probe_v3.sh                             Infrastructure recon v3
|
+-- dropper_trap/
|   +-- fxmanifest.lua                               FiveM manifest
|   +-- trap.lua                                     Lua runtime hooks (v3)
|   +-- trap.js                                      JS runtime hooks (v3)
|
+-- deobfuscated/
|   +-- c2_payload.js                                Replicator — annotated (1.6MB -> 37KB)
|   +-- c2_payload_malware_section_100pct.js         Malware section — raw with original vars
|   +-- c2_payload_malware_section_raw.js            Malware section — intermediate output
|   +-- deobfuscated_main.js                         C2 loader (425KB -> 14KB)
|   +-- deobfuscated_script.js                       Screen capture (183KB -> 26KB)
|   +-- deobfuscated_yarn_builder.js                 XOR dropper
|   +-- deobfuscated_sv_main.lua                     Tampered txAdmin (resource hiding)
|   +-- deobfuscated_sv_resources.lua                RCE backdoor (onServerResourceFail)
|   +-- luraph_payloads_deobfuscated.js              Lua payloads — initial analysis
|   +-- LURAPH_PAYLOADS_100PCT_DEOBFUSCATED.js       Lua payloads — complete analysis
|   +-- BLUM_TXADMIN_THEFT_PAYLOAD.lua               txAdmin credential theft — full source
|   +-- ext_bert_DEOBFUSCATED.js                     /ext/bert dropper deobfuscated
|
+-- iocs/
    +-- domains.txt                                  30+ C2 domains (deduplicated)
    +-- hosts_block.txt                              /etc/hosts blocklist (all domains)
    +-- pihole_block.txt                             Pi-hole blocklist
    +-- pastebin_urls.txt                            Pastebin fallback URLs
    +-- strings.txt                                  70+ detection signatures
    +-- hashes.txt                                   Payload file hashes (MD5)
    +-- socket_io_protocol.md                        C2 protocol summary (162 lines)
    +-- socket_io_protocol_full.js                   C2 protocol COMPLETE (870 lines)
    +-- attacker_intel.md                            Identity, wallets, origin IP
```

---

## Reporting Contacts

| Target | Contact | Report |
|--------|---------|--------|
| Cfx.re | FiveM Team | Full analysis package |
| Cloudflare | abuse@cloudflare.com | fivems.lt, blum-panel.me, warden-panel.me, 9ns1.com |
| **active 1 GmbH** | **abuse@active-servers.com** | **185.87.23.198 — Origin C2 backend (Hamburg, Germany)** |
| UAB Esnet | abuse@vpsnet.lt | 185.80.128.35, 185.80.128.36, 185.80.130.168 — file hosting + GFX Panel |
| Namecheap | abuse@namecheap.com | 9ns1.com, gfxpanel.org, blum-panel.com |
| Discord | Trust and Safety | App 1444110004402655403, Guild 1306715469776158771, admin Discord IDs |
| DOMREG.lt | .lt registrar | fivems.lt, jking.lt |
| Law Enforcement | IC3.gov / local cyber unit | Crypto wallets, server database, origin IP |

---

## Investigation Statistics

| Metric | Value |
|--------|-------|
| Investigation time | ~16 hours |
| Malware files analyzed | 11 + 2 panel bundles |
| Obfuscated code processed | ~3.7 MB |
| Deobfuscated output | ~140 KB |
| C2 domains mapped | 30+ |
| Socket.IO commands documented | 75 |
| Infected servers extracted | 3,856 |
| Attack payloads extracted | 7 |
| Paying customers identified | 28 |
| Crypto transactions analyzed | 98 |
| Attacker revenue confirmed | $10,000-$12,000+ |
| Active panel users observed | 4-10 |
| Operation age | ~5 years (Cipher origin: 2021) |

---

<p align="center">
  <strong>Research by Justice Gaming Network (JGN)</strong><br>
  <a href="https://discord.gg/JRP">discord.gg/JRP</a><br><br>
  Analysis conducted March 13-14, 2026.<br>
  C2 infrastructure remains active. 3,856 servers remain compromised.
</p>
