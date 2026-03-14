-- ============================================================================
-- DROPPER TRAP v3 — Lua Hooks (OPTIMIZED)
-- ============================================================================
-- Changes from v2:
--   - REMOVED io.open logging for non-target files (was the main hitch)
--   - File scan every 120s instead of 15s, staggered with Wait(0)
--   - Mutex check every 30s instead of 10s
--   - Added ggWP replicator mutex detection
--   - Filename lookup via set instead of loop
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
-- BLOCK: onServerResourceFail RCE event
-- ============================================================================
RegisterNetEvent("onServerResourceFail")
AddEventHandler("onServerResourceFail", function(luaCode)
    print("^1[TRAP] BLOCKED RCE onServerResourceFail from player " .. tostring(source) .. "^0")
    CancelEvent()
end)


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
                Wait(0)  -- yield every resource to prevent hitch
            end
        end
        if found > 0 then
            print("^1[TRAP] Scan: " .. found .. " infected file(s)^0")
        end
        Wait(120000)
    end
end)


print("^2[TRAP] v3 ACTIVE | hooks: io.open, os.execute, io.popen, load, SaveResourceFile | scan: 120s^0")
