-- ============================================================================
-- DROPPER TRAP v4 — Lua Hooks (BEHAVIORAL + OPTIMIZED)
-- ============================================================================
-- Changes from v3:
--   - BEHAVIORAL: any write to monitor/resource/(cl_playerlist|sv_main|
--     sv_resources).lua from a non-monitor resource is blocked regardless
--     of content. Catches txAdmin tampering even when markers are renamed.
--   - SHADOW: pre-registers known backdoor net events (onServerResourceFail,
--     txadmin:js_create, helpEmptyCode) so the malicious handlers can't run.
--   - MANIFEST WATCHER: hashes every fxmanifest.lua at first scan; alerts on
--     runtime changes (catches manifest tampering regardless of content).
--   - REPORTING: optional one-line console banner at startup with the issue
--     submission URL. No automatic reporting; copy-paste only.
--
-- IOC SOURCE OF TRUTH: iocs/blum_iocs.json in this repo. The lists below are
-- a runtime mirror; when updating, edit the JSON first and mirror here.
-- ============================================================================

local SUSPICIOUS_PATTERNS = {
    "String.fromCharCode",
    "fromCharCode",
    "bertjj", "bertJJ",
    "miauss", "miausas",
    "fivems.lt",
    "9ns1.com",
    "blum-panel",
    "warden-panel",
    "cipher-panel",
    "gfxpanel",
    "RESOURCE_EXCLUDE",
    "isExcludedResource",
    "onServerResourceFail",
    "decompressFromUTF16",
    "\\u15E1",
    "ggWP",
    "helpEmptyCode",
    "JohnsUrUncle",
    "txadmin:js_create",
}

local KNOWN_TARGETS = {
    "yarn_builder.js", "webpack_builder.js",
    "sv_main.lua", "sv_resources.lua",
    "main.js", "script.js",
    "babel_config.js", "jest_mock.js",
    "mock_data.js", "commands.js",
    "cl_playerlist.lua",
}

-- O(1) lookup
local TARGET_SET = {}
for _, t in ipairs(KNOWN_TARGETS) do TARGET_SET[t] = true end

local blockedCount = 0

local function isSuspicious(content)
    if not content or type(content) ~= "string" then return nil end
    for _, pattern in ipairs(SUSPICIOUS_PATTERNS) do
        if content:find(pattern, 1, true) then return pattern end
    end
    return nil
end

local function isKnownTarget(filepath)
    if not filepath then return false end
    local name = filepath:match("([^/\\]+)$")
    return name and TARGET_SET[name] or false
end

-- Behavioral guard: writes to these txAdmin monitor files from a non-monitor
-- resource are tampering regardless of content. Catches the family even when
-- they rotate marker strings.
local PROTECTED_TXADMIN_FILES = {
    ["cl_playerlist.lua"] = true,
    ["sv_main.lua"] = true,
    ["sv_resources.lua"] = true,
}

local function isProtectedTxAdminPath(filepath)
    if not filepath then return false end
    local lower = filepath:lower()
    if not lower:find("monitor") then return false end
    local name = filepath:match("([^/\\]+)$")
    return name and PROTECTED_TXADMIN_FILES[name:lower()] or false
end

local function getResource()
    return GetInvokingResource() or GetCurrentResourceName() or "unknown"
end


-- ============================================================================
-- HOOK: io.open — ONLY wraps writes to known target files
-- Everything else passes through with ZERO overhead
-- ============================================================================
local origIoOpen = io.open
io.open = function(filepath, mode, ...)
    mode = mode or "r"

    -- Fast path: reads pass straight through
    if not (mode:find("w") or mode:find("a")) then
        return origIoOpen(filepath, mode, ...)
    end

    -- Fast path: not a target = pass through silently (NO LOGGING)
    if not isKnownTarget(filepath) then
        return origIoOpen(filepath, mode, ...)
    end

    -- Only reaches here for writes to known target files
    local realHandle = origIoOpen(filepath, mode, ...)
    if not realHandle then return nil end

    local fakeHandle = {}
    setmetatable(fakeHandle, {__index = realHandle})

    fakeHandle.write = function(self, data, ...)
        -- BEHAVIORAL: any write to a txAdmin monitor file from a resource
        -- other than 'monitor' is tampering regardless of content. This
        -- defends against marker rotation by Blum-family variants.
        if isProtectedTxAdminPath(filepath) then
            local invoker = getResource()
            if invoker ~= "monitor" and invoker ~= "dropper_trap" then
                blockedCount = blockedCount + 1
                print("^1[TRAP] BLOCKED txAdmin tamper: " .. tostring(filepath) ..
                      " written by " .. invoker .. " (behavioral; content not checked)^0")
                return
            end
        end
        if type(data) == "string" then
            local match = isSuspicious(data)
            if match then
                blockedCount = blockedCount + 1
                print("^1[TRAP] BLOCKED " .. tostring(filepath) .. " | " .. match .. " | " .. getResource() .. "^0")
                return
            end
        end
        return realHandle:write(data, ...)
    end

    fakeHandle.close = function(self)
        return realHandle:close()
    end

    return fakeHandle
end


-- ============================================================================
-- HOOK: os.execute + io.popen — ALWAYS BLOCK
-- ============================================================================
os.execute = function(command, ...)
    print("^1[TRAP] BLOCKED os.execute: " .. tostring(command):sub(1, 100) .. " | " .. getResource() .. "^0")
    return nil, "exit", 1
end

local origIoPopen = io.popen
if origIoPopen then
    io.popen = function(command, ...)
        print("^1[TRAP] BLOCKED io.popen: " .. tostring(command):sub(1, 100) .. " | " .. getResource() .. "^0")
        return nil, "blocked"
    end
end


-- ============================================================================
-- HOOK: load / loadstring — BLOCK backdoor patterns
-- ============================================================================
local origLoad = load
load = function(chunk, ...)
    if type(chunk) == "string" then
        local match = isSuspicious(chunk)
        if match then
            print("^1[TRAP] BLOCKED load() | " .. match .. " | " .. getResource() .. "^0")
            return function() end, nil
        end
    end
    return origLoad(chunk, ...)
end

local origLoadstring = loadstring
if origLoadstring then
    loadstring = function(chunk, ...)
        if type(chunk) == "string" then
            local match = isSuspicious(chunk)
            if match then
                print("^1[TRAP] BLOCKED loadstring() | " .. match .. " | " .. getResource() .. "^0")
                return function() end, nil
            end
        end
        return origLoadstring(chunk, ...)
    end
end


-- ============================================================================
-- HOOK: SaveResourceFile — BLOCK backdoor content
-- ============================================================================
local origSaveResourceFile = SaveResourceFile
if origSaveResourceFile then
    SaveResourceFile = function(resourceName, fileName, data, dataLength, ...)
        if isSuspicious(data) then
            blockedCount = blockedCount + 1
            print("^1[TRAP] BLOCKED SaveResourceFile: " .. resourceName .. "/" .. fileName .. " | " .. getResource() .. "^0")
            return false
        end
        return origSaveResourceFile(resourceName, fileName, data, dataLength, ...)
    end
end


-- ============================================================================
-- SHADOW REGISTER: known backdoor net events
-- We register these first so our handler runs before any malicious handler
-- and CancelEvent()s the propagation. IMPORTANT: dropper_trap must load
-- before any infected resource for this defense to work — put `ensure
-- dropper_trap` as the FIRST `ensure` line in your resources.cfg.
--
-- To add a new family event name: edit iocs/blum_iocs.json under
-- txadmin_tampering.backdoor_event_names, then mirror the change here.
-- ============================================================================
local SHADOW_EVENTS = {
    "onServerResourceFail",   -- Blum/Warden server-side RCE
    "txadmin:js_create",      -- Blum JS execution variant
    "helpEmptyCode",          -- defensive: in case the family ever flips it server-side
}

for _, eventName in ipairs(SHADOW_EVENTS) do
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function(...)
        blockedCount = blockedCount + 1
        print("^1[TRAP] BLOCKED backdoor event '" .. eventName ..
              "' from player " .. tostring(source) .. "^0")
        CancelEvent()
    end)
end


-- ============================================================================
-- PERIODIC: Mutex check — every 30s (just reads GlobalState, near-zero cost)
-- ============================================================================
CreateThread(function()
    while true do
        Wait(30000)
        for _, name in ipairs({"miauss", "miausas", "ggWP"}) do
            local val = GlobalState[name]
            if val ~= nil then
                print("^1[TRAP] MUTEX: GlobalState." .. name .. " = " .. tostring(val) .. " — CLEARING^0")
                GlobalState[name] = nil
            end
        end
    end
end)


-- ============================================================================
-- MANIFEST WATCHER: hash every fxmanifest at first scan; alert on changes.
-- Catches manifest tampering at runtime regardless of marker rotation. Blum
-- typically modifies fxmanifest.lua to inject hidden script paths; this
-- detects any change to manifest content after the first observation.
-- ============================================================================
local manifestHashes = {}

-- Simple non-cryptographic hash sufficient to detect any manifest change.
-- Lua doesn't ship sha2 in FiveM's runtime; collision resistance isn't
-- needed here because we only compare against the prior value of the same
-- file, not across files.
local function simpleHash(s)
    local h = 0
    for i = 1, #s do
        h = (h * 31 + s:byte(i)) % 2147483647
    end
    return h
end


-- ============================================================================
-- PERIODIC: File scan — every 120s, staggered with Wait(0) between resources
-- ============================================================================
CreateThread(function()
    Wait(30000)  -- let server finish booting
    while true do
        local numResources = GetNumResources()
        local found = 0
        for i = 0, numResources - 1 do
            local resName = GetResourceByFindIndex(i)
            if resName and resName ~= "dropper_trap" then
                for _, target in ipairs(KNOWN_TARGETS) do
                    local content = LoadResourceFile(resName, target)
                    if content and isSuspicious(content) then
                        found = found + 1
                        print("^1[TRAP] INFECTED: " .. resName .. "/" .. target .. "^0")
                    end
                end
                -- Manifest watcher: capture hash on first sight; alert on diff.
                local manifest = LoadResourceFile(resName, "fxmanifest.lua") or
                                 LoadResourceFile(resName, "__resource.lua")
                if manifest then
                    local h = simpleHash(manifest)
                    if manifestHashes[resName] == nil then
                        manifestHashes[resName] = h
                    elseif manifestHashes[resName] ~= h then
                        print("^1[TRAP] MANIFEST CHANGED at runtime: " .. resName ..
                              " — possible tampering, review fxmanifest.lua^0")
                        manifestHashes[resName] = h
                    end
                end
                Wait(0)  -- yield every resource to prevent hitch
            end
        end
        if found > 0 then
            print("^1[TRAP] Scan: " .. found .. " infected file(s)^0")
            print("^3[TRAP] To share findings (optional, no auto-reporting): https://github.com/ImJer/blum-panel-fivem-backdoor-analysis/issues/new?template=scanner-findings.md^0")
        end
        Wait(120000)
    end
end)


print("^2[TRAP] v4 ACTIVE | hooks: io.open(behavioral txAdmin block) os.execute io.popen load SaveResourceFile | shadow events: " .. tostring(#SHADOW_EVENTS) .. " | manifest watcher: ON | scan: 120s^0")
print("^2[TRAP] To report unrecognised blocks (optional): https://github.com/ImJer/blum-panel-fivem-backdoor-analysis/issues/new?template=scanner-findings.md  (no auto-reporting)^0")
