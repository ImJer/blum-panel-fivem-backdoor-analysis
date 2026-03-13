-- ============================================================================
-- DROPPER TRAP v2 — Lua Hooks (BLOCKS + LOGS)
-- ============================================================================
-- This version BLOCKS malicious writes and LOGS them.
-- Clean writes pass through normally.
-- ============================================================================

local SUSPICIOUS_PATTERNS = {
    "String.fromCharCode",
    "fromCharCode",
    "bertjj", "bertJJ",
    "miauss", "miausas",
    "fivems.lt",
    "RESOURCE_EXCLUDE",
    "isExcludedResource",
    "onServerResourceFail",
    "decompressFromUTF16",
    "\\u15E1",
}

local KNOWN_TARGETS = {
    "yarn_builder.js", "webpack_builder.js",
    "sv_main.lua", "sv_resources.lua",
    "main.js", "script.js",
}

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
    for _, target in ipairs(KNOWN_TARGETS) do
        if filepath:find(target, 1, true) then return true end
    end
    return false
end

local function getResource()
    return GetInvokingResource() or GetCurrentResourceName() or "unknown"
end


-- ============================================================================
-- HOOK: io.open — BLOCKS writes to known targets with suspicious content
-- ============================================================================
local origIoOpen = io.open
io.open = function(filepath, mode, ...)
    mode = mode or "r"

    if not (mode:find("w") or mode:find("a")) then
        return origIoOpen(filepath, mode, ...)
    end

    local isTarget = isKnownTarget(filepath)

    if isTarget then
        -- Return a FAKE file handle that intercepts :write()
        local realHandle = origIoOpen(filepath, mode, ...)
        if not realHandle then return nil end

        local fakeHandle = {}
        setmetatable(fakeHandle, {__index = realHandle})

        fakeHandle.write = function(self, ...)
            local data = table.concat({...})
            local match = isSuspicious(data)
            if match then
                blockedCount = blockedCount + 1
                print("^1======================================================================^0")
                print("^1[TRAP] ████ DROPPER WRITE BLOCKED ████^0")
                print(string.format("^1[TRAP] Resource:  %q^0", getResource()))
                print(string.format("^1[TRAP] File:      %s^0", tostring(filepath)))
                print(string.format("^1[TRAP] Pattern:   %s^0", match))
                print(string.format("^1[TRAP] Data size: %d bytes^0", #data))
                print(string.format("^1[TRAP] Preview:   %s^0", data:sub(1, 150)))
                print(string.format("^1[TRAP] Total blocks so far: %d^0", blockedCount))
                print("^1======================================================================^0")
                -- DO NOT write — return without calling real write
                return
            end
            return realHandle:write(...)
        end

        fakeHandle.close = function(self)
            return realHandle:close()
        end

        return fakeHandle
    else
        -- Not a known target — log but allow
        local res = getResource()
        if res ~= "none" and res ~= "dropper_trap" then
            print(string.format("^5[TRAP] io.open(%s, %s) by %q^0", tostring(filepath):sub(-50), mode, res))
        end
        return origIoOpen(filepath, mode, ...)
    end
end


-- ============================================================================
-- HOOK: os.execute — ALWAYS BLOCK (no legitimate FiveM use)
-- ============================================================================
local origOsExecute = os.execute
os.execute = function(command, ...)
    print("^1[TRAP] ████ os.execute BLOCKED ████^0")
    print(string.format("^1[TRAP] Resource: %q^0", getResource()))
    print(string.format("^1[TRAP] Command:  %s^0", tostring(command):sub(1, 200)))
    -- BLOCK — return failure
    return nil, "exit", 1
end


-- ============================================================================
-- HOOK: io.popen — ALWAYS BLOCK
-- ============================================================================
local origIoPopen = io.popen
if origIoPopen then
    io.popen = function(command, mode, ...)
        print("^1[TRAP] ████ io.popen BLOCKED ████^0")
        print(string.format("^1[TRAP] Resource: %q^0", getResource()))
        print(string.format("^1[TRAP] Command:  %s^0", tostring(command):sub(1, 200)))
        return nil, "blocked by dropper_trap"
    end
end


-- ============================================================================
-- HOOK: load / loadstring — BLOCK if content matches backdoor patterns
-- ============================================================================
local origLoad = load
load = function(chunk, ...)
    if type(chunk) == "string" then
        local match = isSuspicious(chunk)
        if match then
            print("^1[TRAP] ████ MALICIOUS load() BLOCKED ████^0")
            print(string.format("^1[TRAP] Resource: %q^0", getResource()))
            print(string.format("^1[TRAP] Pattern:  %s^0", match))
            print(string.format("^1[TRAP] Code:     %s^0", chunk:sub(1, 200)))
            -- Return a function that does nothing
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
                print("^1[TRAP] ████ MALICIOUS loadstring() BLOCKED ████^0")
                print(string.format("^1[TRAP] Resource: %q^0", getResource()))
                return function() end, nil
            end
        end
        return origLoadstring(chunk, ...)
    end
end


-- ============================================================================
-- HOOK: SaveResourceFile — BLOCK if writing backdoor content
-- ============================================================================
local origSaveResourceFile = SaveResourceFile
if origSaveResourceFile then
    SaveResourceFile = function(resourceName, fileName, data, dataLength, ...)
        local match = isSuspicious(data)
        local isTarget = isKnownTarget(fileName)

        if match or isTarget then
            if match then
                blockedCount = blockedCount + 1
                print("^1[TRAP] ████ SaveResourceFile BLOCKED ████^0")
                print(string.format("^1[TRAP] Resource writing: %q^0", getResource()))
                print(string.format("^1[TRAP] Target: %s/%s^0", resourceName, fileName))
                print(string.format("^1[TRAP] Pattern: %s^0", match))
                return false
            else
                -- Known target but no suspicious content — allow but warn
                print(string.format("^3[TRAP] WARNING: SaveResourceFile to target %s/%s by %q^0", resourceName, fileName, getResource()))
            end
        end

        return origSaveResourceFile(resourceName, fileName, data, dataLength, ...)
    end
end


-- ============================================================================
-- BLOCK: onServerResourceFail RCE event
-- ============================================================================
RegisterNetEvent("onServerResourceFail")
AddEventHandler("onServerResourceFail", function(luaCode)
    print("^1[TRAP] ████ RCE ATTEMPT VIA onServerResourceFail BLOCKED ████^0")
    print(string.format("^1[TRAP] Source player: %s^0", tostring(source)))
    print(string.format("^1[TRAP] Code: %s^0", tostring(luaCode):sub(1, 300)))
    CancelEvent()
end)


-- ============================================================================
-- PERIODIC: GlobalState mutex check + file infection scan
-- ============================================================================
CreateThread(function()
    while true do
        Wait(10000)
        local mutexNames = {"miauss", "miausas"}
        for _, name in ipairs(mutexNames) do
            local val = GlobalState[name]
            if val ~= nil then
                print("^1[TRAP] ████ BACKDOOR MUTEX ACTIVE ████^0")
                print(string.format("^1[TRAP] GlobalState.%s = %q^0", name, tostring(val)))
                print("^1[TRAP] Attempting to clear mutex...^0")
                GlobalState[name] = nil
            end
        end
    end
end)

CreateThread(function()
    Wait(5000)
    while true do
        local numResources = GetNumResources()
        for i = 0, numResources - 1 do
            local resName = GetResourceByFindIndex(i)
            if resName then
                for _, target in ipairs(KNOWN_TARGETS) do
                    local content = LoadResourceFile(resName, target)
                    if content then
                        local match = isSuspicious(content)
                        if match then
                            print("^1[TRAP] ████ INFECTED FILE FOUND ████^0")
                            print(string.format("^1[TRAP] Resource: %s / %s^0", resName, target))
                            print(string.format("^1[TRAP] Pattern: %s^0", match))
                        end
                    end
                end
            end
        end
        Wait(15000)
    end
end)

print("^2[TRAP] ============================================^0")
print("^2[TRAP] Dropper trap v2 ACTIVE — BLOCKING MODE^0")
print("^2[TRAP] Malicious writes will be BLOCKED, not just logged^0")
print("^2[TRAP] os.execute and io.popen BLOCKED entirely^0")
print("^2[TRAP] onServerResourceFail RCE BLOCKED^0")
print("^2[TRAP] GlobalState mutex auto-cleared every 10s^0")
print("^2[TRAP] ============================================^0")
