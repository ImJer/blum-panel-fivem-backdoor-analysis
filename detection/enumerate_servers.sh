#!/bin/bash
# ============================================================
# BLUM PANEL — INFECTED SERVER ENUMERATION
# Connects to the live Socket.IO C2 and attempts to pull server lists
# Run: bash enumerate_servers.sh 2>&1 | tee server_enum_results.txt
# ============================================================

cd ~/blum-probe
npm install socket.io-client 2>/dev/null

# ============================================================
# APPROACH 1: Connect as Socket.IO client, try panel-side events
# ============================================================
cat > enum_servers.js << 'ENUMEOF'
const { io } = require("socket.io-client");
const fs = require("fs");

const C2_URLS = ["https://fivems.lt", "https://9ns1.com"];
const API_KEYS = ["bert", "zXeAH", "dev", "null", "panel", "blum", "miauss"];

// Collect all data received
const allData = {};
let eventLog = [];

function logEvent(source, event, data) {
    const entry = { timestamp: Date.now(), source, event, data };
    eventLog.push(entry);
    console.log(`[${source}] Event: ${event}`);
    if (typeof data === 'object') {
        console.log(JSON.stringify(data, null, 2).substring(0, 2000));
    } else if (typeof data === 'string') {
        console.log(data.substring(0, 500));
    }
    console.log("---");
}

async function probeC2(url, apiKey) {
    return new Promise((resolve) => {
        const tag = `${url}/${apiKey}`;
        console.log(`\n========== Connecting to ${tag} ==========`);

        const socket = io(url, {
            reconnection: false,
            transports: ["websocket"],
            timeout: 10000,
            forceNew: true,
        });

        const timer = setTimeout(() => {
            console.log(`[${tag}] Timeout — disconnecting`);
            socket.disconnect();
            resolve();
        }, 15000);

        socket.on("connect", () => {
            console.log(`[${tag}] Connected! SID: ${socket.id}`);

            // Strategy 1: Register as a fake implant to see what the server sends back
            socket.emit("register", {
                serverId: "PROBE-" + Math.random().toString(36).substring(7),
                apiKey: apiKey + "JJ",
                ip: "127.0.0.1:30120",
                servername: "Probe Server",
                license: "probe_license_key",
                isPersonalPC: false,
                resourcename: "probe-resource",
                monitorAppendResult: { status: "success", reason: null, infectionReport: {} }
            });

            // Strategy 2: Try panel-side events that might return server lists
            // These are from the bundle.js analysis
            setTimeout(() => {
                // Try requesting server list (panel perspective)
                socket.emit("servers", { apiKey: apiKey + "JJ" });
                socket.emit("getServers", { apiKey: apiKey + "JJ" });
                socket.emit("server:getPlayers", { apiKey: apiKey + "JJ" });
                socket.emit("admin:getServers", { apiKey: apiKey + "JJ" });

                // Try serverInfo request
                socket.emit("serverInfo", {
                    apiKey: apiKey + "JJ",
                    serverId: "*"
                });

                // Try heartbeat to stay alive
                socket.emit("heartbeat", { 
                    timestamp: Date.now(), 
                    serverId: "PROBE" 
                });
            }, 1000);

            // Strategy 3: Try discord/admin events
            setTimeout(() => {
                socket.emit("discord:getServers", {});
                socket.emit("admin:getInventory", {});
                socket.emit("fs:getResources", { serverId: "*" });
                socket.emit("fs:getConsole", { serverId: "*" });
            }, 2000);
        });

        // Listen for ANY event the server sends
        socket.onAny((event, ...args) => {
            logEvent(tag, event, args.length === 1 ? args[0] : args);
        });

        // Specific events we expect from our deobfuscation
        const watchEvents = [
            "servers", "serverInfo", "server:playersSnapshot",
            "heartbeat_ack", "register", "registered",
            "adminCreated", "groupData", "inventoryData",
            "jobData", "jobsListData", "error", "disconnect",
            "connect_error", "unauthorized", "authenticated",
            "serverList", "serverData", "playersSnapshot"
        ];

        for (const ev of watchEvents) {
            socket.on(ev, (data) => {
                logEvent(tag, `[SPECIFIC] ${ev}`, data);
            });
        }

        socket.on("connect_error", (err) => {
            console.log(`[${tag}] Connection error: ${err.message}`);
            clearTimeout(timer);
            resolve();
        });

        socket.on("disconnect", (reason) => {
            console.log(`[${tag}] Disconnected: ${reason}`);
            clearTimeout(timer);
            resolve();
        });
    });
}

async function main() {
    console.log("=== BLUM PANEL SERVER ENUMERATION ===");
    console.log("Time:", new Date().toISOString());
    console.log("");

    // Try each C2 with each API key
    for (const url of C2_URLS) {
        for (const key of API_KEYS.slice(0, 3)) { // First 3 keys to avoid rate limiting
            await probeC2(url, key);
        }
    }

    // Save all collected data
    fs.writeFileSync("enum_event_log.json", JSON.stringify(eventLog, null, 2));
    console.log(`\n\n=== COMPLETE ===`);
    console.log(`Total events captured: ${eventLog.length}`);
    console.log(`Saved to enum_event_log.json`);

    // Give remaining events a moment to arrive
    await new Promise(r => setTimeout(r, 3000));
    
    // Update log file
    fs.writeFileSync("enum_event_log.json", JSON.stringify(eventLog, null, 2));
    process.exit(0);
}

main().catch(console.error);
ENUMEOF

echo "=========================================="
echo "Running Socket.IO enumeration probe..."
echo "=========================================="
timeout 120 node enum_servers.js 2>&1

echo ""
echo "=========================================="
echo "APPROACH 2: HTTP API probing for server lists"
echo "=========================================="

# The panel redirects to 185.87.23.198:5000 for /api routes
# But the Socket.IO on the Cloudflare endpoints IS live
# Try fetching server data via HTTP through Cloudflare

for host in fivems.lt 9ns1.com; do
    echo "--- $host ---"
    
    # Try REST API endpoints that might list servers
    for path in "/api/servers" "/api/v1/servers" "/servers" "/api/server/list" \
                "/api/admin/servers" "/api/panel/servers"; do
        result=$(curl -s -o /tmp/api_body -w "%{http_code}:%{size_download}" \
            "https://$host$path" \
            -H "User-Agent: Mozilla/5.0" \
            -H "Accept: application/json" \
            -H "Authorization: Bearer test" \
            --connect-timeout 3 2>/dev/null)
        code=$(echo $result | cut -d: -f1)
        size=$(echo $result | cut -d: -f2)
        if [ "$code" != "000" ] && [ "$code" != "404" ]; then
            preview=$(head -c 300 /tmp/api_body 2>/dev/null | tr '\n\r' '  ')
            echo "$path → HTTP $code ($size bytes)"
            [ -n "$preview" ] && echo "  $preview"
        fi
    done
    echo ""
done

echo ""
echo "=========================================="
echo "APPROACH 3: Socket.IO HTTP polling for data"
echo "=========================================="

# Use Socket.IO's HTTP long-polling transport to interact
for host in fivems.lt 9ns1.com; do
    echo "--- $host Socket.IO polling ---"
    
    # Get a session ID first
    SID_RESPONSE=$(curl -s "https://$host/socket.io/?EIO=4&transport=polling" 2>/dev/null)
    echo "Handshake: $SID_RESPONSE"
    
    # Extract SID
    SID=$(echo "$SID_RESPONSE" | grep -oP '"sid":"[^"]*"' | cut -d'"' -f4)
    echo "SID: $SID"
    
    if [ -n "$SID" ]; then
        # Send register event via polling
        # Socket.IO protocol: 42["event", {data}]
        REGISTER_MSG='42["register",{"serverId":"HTTPPROBE","apiKey":"bertJJ","ip":"127.0.0.1:30120","servername":"HTTP Probe"}]'
        
        curl -s "https://$host/socket.io/?EIO=4&transport=polling&sid=$SID" \
            -X POST \
            -H "Content-Type: text/plain;charset=UTF-8" \
            -d "$REGISTER_MSG" \
            -w "\nPOST: HTTP %{http_code}\n" 2>/dev/null
        
        # Read response
        sleep 2
        RESPONSE=$(curl -s "https://$host/socket.io/?EIO=4&transport=polling&sid=$SID" 2>/dev/null)
        echo "Response: $RESPONSE"
        
        # Try servers event
        SERVERS_MSG='42["servers",{"apiKey":"bertJJ"}]'
        curl -s "https://$host/socket.io/?EIO=4&transport=polling&sid=$SID" \
            -X POST \
            -H "Content-Type: text/plain;charset=UTF-8" \
            -d "$SERVERS_MSG" 2>/dev/null
        
        sleep 2
        RESPONSE2=$(curl -s "https://$host/socket.io/?EIO=4&transport=polling&sid=$SID" 2>/dev/null)
        echo "Servers response: $RESPONSE2"
        
        # Try getPlayersDetailed
        PLAYERS_MSG='42["getPlayersDetailed",{"apiKey":"bertJJ"}]'
        curl -s "https://$host/socket.io/?EIO=4&transport=polling&sid=$SID" \
            -X POST \
            -H "Content-Type: text/plain;charset=UTF-8" \
            -d "$PLAYERS_MSG" 2>/dev/null
        
        sleep 2
        RESPONSE3=$(curl -s "https://$host/socket.io/?EIO=4&transport=polling&sid=$SID" 2>/dev/null)
        echo "Players response: $RESPONSE3"
    fi
    echo ""
done

echo ""
echo "=========================================="  
echo "ENUMERATION COMPLETE"
echo "=========================================="
echo ""
echo "Check enum_event_log.json for all captured Socket.IO events"
echo "Upload both this output and enum_event_log.json"
