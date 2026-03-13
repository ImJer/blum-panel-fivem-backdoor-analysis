# Blum Panel Backdoor — Complete Deobfuscation & Analysis

> **Full reverse-engineering of the Blum Panel (blum-panel.me / warden-panel.me) FiveM backdoor toolkit.**
> Includes detection scanner, C2 domain blocklist, dropper trap resource, and every deobfuscated source file.
> **Attacker:** bertjj / miauss — **C2:** fivems.lt — **Discord:** discord.com/invite/VB8mdVjrzd

---

## TL;DR — What Blum Panel Does

Blum Panel is a FiveM server exploitation toolkit that:

1. **Phones home every 60 seconds** to `fivems.lt` and eval()'s whatever JavaScript the attacker sends
2. **Replicates itself** into every resource on the server via XOR-encrypted dropper files hidden in innocent-looking paths like `server/modules/babel_config.js`
3. **Steals txAdmin credentials** by hooking all HTTP requests and capturing `X-TxAdmin-Token` headers, then creates a backdoor admin account named `"JohnsUrUncle"` with full permissions
4. **Streams victims' screens live** to the attacker via WebRTC through an invisible WebGL canvas overlay
5. **Intercepts private messages** between players via FiveM's `privateChatMap`
6. **Injects RCE backdoors** into txAdmin's Lua files allowing arbitrary code execution via fake events
7. **Hides itself** from the txAdmin dashboard by patching `sv_main.lua` to filter infected resources from the resource list
8. **Forges file timestamps** to make modified files appear unaltered
9. **Modifies `server.cfg`** to auto-start infected resources, inserting `ensure` lines at random positions among existing entries

The infection chain: **dropper** (XOR-encrypted .js file) → **C2 loader** (main.js, phones home) → **replicator** (c2_payload.txt, 1.6MB eval'd from C2, spreads to all resources) → **screen capture** (script.js, WebRTC streaming).

---

## Files Analyzed

| File | Size | Role |
|------|------|------|
| `main.js` | 425 KB | Server-side C2 loader — connects to 23+ domains, eval()'s payloads |
| `script.js` | 183 KB | Client-side WebRTC screen capture + chat interception |
| `c2_payload.txt` | 1.6 MB | **Live replication engine** — served by fivems.lt, writes droppers into all resources |
| `yarn_builder.js` | 43 KB | XOR dropper (key 169/189, 2 blocks) |
| `webpack_builder.js` | 632 KB | XOR dropper (34 blocks, different keys) |
| `babel_config.js` | 20 KB | XOR dropper (key 204, 1 block) |
| `sv_main.lua` | 18 KB | Tampered txAdmin — RESOURCE_EXCLUDE list hides malicious resources |
| `sv_resources.lua` | 2 KB | Tampered txAdmin — `onServerResourceFail` RCE backdoor |

---

## Obfuscation Architecture (5 Layers)

All files use the same obfuscation family, cracked via the same methodology:

**Layer 1 — Function() Constructor Wrapper:** Entire payload wrapped as string argument to `Function()`. Getter-based object passes runtime references without keywords appearing in code.

**Layer 2 — LZString UTF-16 Compression** (main.js/script.js only): 3,547-char Unicode blob starting with `\u15E1`. Decompresses to pipe-delimited string table.

**Layer 3 — Base-91 Encoding:** Every meaningful string is base-91 encoded. main.js uses 51 per-scope alphabets, script.js uses 70, c2_payload.txt uses a single alphabet with 29,853 decode calls, 10,318 encoded strings, and 22-position rotation.

**Layer 4 — Indirection Arrays:** `aga[]` (419 elements), `_uENFU[]` (276 elements), `UARZT6[]` (3,014 elements). All string/API references go through these by index.

**Layer 5 — Generator State Machines:** 146 generators in main.js, 61 generators + 74 switch-case machines in c2_payload.txt. `function*` with `while(true) switch(state)` flattens all control flow.

**Dropper obfuscation** is separate — simple XOR cipher: `String.fromCharCode(a[i]^k)` with keys 169, 189, 204, etc.

---

## C2 Infrastructure

### Primary Endpoints
| Endpoint | Purpose |
|----------|---------|
| `https://fivems.lt/bertJJ` | Primary payload delivery → eval() |
| `https://fivems.lt/bertJJgg` | Fallback #1 → eval() |
| `https://fivems.lt/bertJJcfxre` | Fallback #2 → eval() |

C2 fingerprints requests — only responds to Node.js User-Agent headers. Retry: 3 endpoints × 3 attempts, 10s timeout, 120s backoff. Also uses persistent Socket.IO WebSocket with 60s heartbeat.

### 23+ Hardcoded Domains
```
0xchitado.com  2312321321321213.com  2ns3.net  5mscripts.net  bhlool.com
bybonvieux.com  fivemgtax.com  flowleakz.org  giithub.net  iwantaticket.org
jking.lt  kutingplays.com  l00x.org  monloox.com  noanimeisgay.com
ryenz.net  spacedev.fr  trezz.org  z1lly.org  warden-panel.me
2nit32.com  useer.it.com  wsichkidolu.com
```

### Pastebin Fallbacks
`pastebin.com/raw/g5iZ1xha`, `Sm9p9tkm`, `eViHnPMt`, `kwW3u4U5` — all return `// Empty` (dormant).

---

## Replicator Behavior (c2_payload.txt — Fully Deobfuscated)

The replicator is memory-only — never written to disk. It infects 4 components:

### Component 1: XOR Dropper Injection
- Scans all resources recursively (max depth 5)
- Picks random subdirectory from 68+ options, random filename from 40+ options
- Writes XOR-encrypted dropper, injects path into `fxmanifest.lua`
- Detects wildcard patterns in manifests and skips if unnecessary
- Specifically targets "yarn" and "webpack" resources

### Component 2: server.cfg Modification
- Inserts `ensure <resource>` at random positions among existing entries
- Windows: removes hidden/system/readonly flags via `attrib`

### Component 3: txAdmin sv_main.lua Patching
- Replaces `txaReportResources()` with version filtering 62+ resource name patterns from dashboard

### Component 4: txAdmin RCE + Credential Theft
- Appends `onServerResourceFail` RCE to `sv_resources.lua`
- Appends `helpEmptyCode` client exec to `cl_playerlist.lua`
- **Hooks `PerformHttpRequest()`** to steal `X-TxAdmin-Token` from ALL HTTP traffic
- Creates backdoor admin **"JohnsUrUncle"** with `all_permissions`
- Exposes `txadmin:js_create` event for remote admin account creation

### Dropper Filename Pool (40+)
```
env_backup.js  cache_old.js  build_cache.js  vite_temp.js  webpack_bundle.js
babel_config.js  eslint_rc.js  jest_setup.js  test_utils.js  mock_data.js
utils_lib.js  helper_functions.js  config_settings.js  runtime_module.js
sync_worker.js  queue_handler.js  session_store.js  event_emitter.js
hook_system.js  patch_update.js  v1_config.js  v2_settings.js  jest_mock.js
database.js  events.js  commands.js  functions.js  main.js  index.js  app.js
core.js  lib.js  webpack_chunk.js  vite_plugin.js  babel_preset.js  ...
```

### Dropper Directory Pool (68+)
```
html/js  html/scripts  html/assets  html/lib  html/vendor  html/plugins
client/lib  client/vendor  client/plugins  client/modules  client/scripts
server/utils  server/lib  server/helpers  server/modules  server/plugins
data  config  settings  locales  temp  cache  storage  logs
node_modules/internal  node_modules/.cache  node_modules/.bin
dist  build  public  static  assets  src  libs  vendor  middleware  ...
```

### Anti-Detection
- **Timestamp forgery:** `fs.utimesSync()` + PowerShell `LastWriteTime`/`CreationTime` restoration
- **Windows stealth:** `attrib +h +s +r` after modification
- **Random insertion:** server.cfg `ensure` among existing entries
- **Wildcard awareness:** Skips manifest injection if wildcards auto-include .js
- **Dual mutex:** `GlobalState.ggWP` (replicator) / `GlobalState.miauss` (dropper)

---

## Detection

### Quick Scan
```bash
bash detection/scan.sh
```

### Manual
```bash
grep -rn "String.fromCharCode(a\[i\]\^k)" --include="*.js"
grep -rn "bertjj\|bertJJ\|miauss\|miausas\|fivems\.lt\|VB8mdVjrzd" --include="*.js" --include="*.lua"
grep -rn "RESOURCE_EXCLUDE\|onServerResourceFail\|helpEmptyCode\|JohnsUrUncle" --include="*.lua"
```

### GlobalState Check (FiveM console)
```lua
if GlobalState.miauss then print("DROPPER: "..GlobalState.miauss) end
if GlobalState.ggWP then print("REPLICATOR: "..GlobalState.ggWP) end
```

---

## Remediation

1. **Block C2:** `echo "0.0.0.0 fivems.lt" >> /etc/hosts` + run `detection/block_c2.sh`
2. **Clear mutexes:** `GlobalState.miauss = nil` / `GlobalState.ggWP = nil`
3. **Delete droppers:** Find all files with `String.fromCharCode(a[i]^k)` and remove them
4. **Clean manifests:** Remove injected `server_script`/`shared_script` entries from `fxmanifest.lua` files
5. **Restore txAdmin:** Download `sv_main.lua`, `sv_resources.lua`, and `cl_playerlist.lua` from official txAdmin GitHub
6. **Clean server.cfg:** Remove unfamiliar `ensure` lines
7. **Check txAdmin admins:** Remove any account named "JohnsUrUncle" or unrecognized accounts
8. **Deploy trap (optional):** Copy `dropper_trap/` to resources, `ensure dropper_trap` first in server.cfg

---

## Attacker IOCs

**Handles:** bertjj, bertjjgg, bertjjcfxre, miausas, miauss
**Discord:** discord.com/invite/VB8mdVjrzd
**Panels:** blum-panel.me, warden-panel.me
**txAdmin backdoor account:** JohnsUrUncle
**txAdmin events:** `onServerResourceFail`, `helpEmptyCode`, `txadmin:js_create`

---

## Repository Structure
```
├── README.md
├── detection/
│   ├── scan.sh              ← One-command malware scanner
│   └── block_c2.sh          ← C2 blocker (hosts + iptables REJECT)
├── dropper_trap/
│   ├── fxmanifest.lua
│   ├── trap.lua              ← Lua hooks (v3, optimized)
│   └── trap.js               ← JS hooks (v3, async, non-blocking)
├── deobfuscated/
│   ├── c2_payload.js         ← ★ Replicator (1.6MB → 37KB readable)
│   ├── deobfuscated_main.js
│   ├── deobfuscated_script.js
│   ├── deobfuscated_yarn_builder.js
│   ├── deobfuscated_sv_main.lua
│   └── deobfuscated_sv_resources.lua
└── iocs/
    ├── domains.txt
    ├── hosts_block.txt
    ├── pihole_block.txt
    ├── pastebin_urls.txt
    └── strings.txt
```

---

Analysis conducted March 2026. Report to: Cfx.re, Discord Trust & Safety, domain registrars, affected resource developers.
