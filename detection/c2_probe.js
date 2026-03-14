/*
 * ============================================================================
 * BLUM PANEL C2 PASSIVE PROBE — SECURITY RESEARCH ONLY
 * ============================================================================
 * 
 * Connects to fivems.lt Socket.IO C2, registers as a fake infected server,
 * and logs EVERYTHING the C2 sends back. Does NOT execute any commands.
 * Does NOT interact with other infected servers.
 * 
 * Usage: node probe.js [--duration 300]
 * 
 * Output: probe_log_<timestamp>.json
 * ============================================================================
 */

const { io } = require("socket.io-client");
const fs = require("fs");
const crypto = require("crypto");

// ============================================================================
// CONFIG
// ============================================================================

const C2_URL = "https://fivems.lt";
const API_KEY = "bertJJ";
const DURATION = parseInt(process.argv.find((a, i) => process.argv[i-1] === "--duration") || "300") * 1000;

// Generate a believable but fake server identity
const FAKE_SERVER = {
    serverId: crypto.randomBytes(16).toString("hex"),
    apiKey: API_KEY,
    ip: `192.168.${Math.floor(Math.random()*254)+1}.${Math.floor(Math.random()*254)+1}:30120`,
    servername: "Los Santos Roleplay",
    license: "fake_" + crypto.randomBytes(8).toString("hex"),
    isPersonalPC: false,
    resourcename: "webpack_builder",
    monitorAppendResult: {
        status: "success",
        reason: "4 of 4 components infected (0 new injections)",
        infectionReport: {
            monitor:    { status: "INFECTED", reason: "Already infected" },
            cl_monitor: { status: "INFECTED", reason: "Already infected" },
            sv_monitor: { status: "INFECTED", reason: "Already infected" },
            webpack:    { status: "INFECTED", reason: "Already infected" }
        }
    }
};

const FAKE_SERVER_INFO = {
    apiKey: API_KEY,
    serverId: FAKE_SERVER.serverId,
    servername: "Los Santos Roleplay",
    username: "Administrator",
    ip: FAKE_SERVER.ip,
    playercount: 48,
    maxcount: 128,
    osEnvironment: "Linux",
    license: FAKE_SERVER.license,
    framework: "QBCore",
    isPersonalPC: false,
    serverUptime: "12h 34m",
    locale: "en-US",
    anticheats: ["Not Found"]
};

// ============================================================================
// LOGGING
// ============================================================================

const startTime = Date.now();
const log = {
    probe_start: new Date().toISOString(),
    c2_url: C2_URL,
    fake_server_id: FAKE_SERVER.serverId,
    connection_events: [],
    received_events: [],
    sent_events: [],
    errors: [],
    raw_packets: []
};

function logEvent(direction, event, data) {
    const entry = {
        timestamp: new Date().toISOString(),
        elapsed_ms: Date.now() - startTime,
        direction: direction,
        event: event,
        data: data
    };
    
    if (direction === "RECV") {
        log.received_events.push(entry);
        console.log(`\x1b[31m[RECV]\x1b[0m ${event}`, typeof data === 'object' ? JSON.stringify(data).substring(0, 500) : data);
    } else if (direction === "SEND") {
        log.sent_events.push(entry);
        console.log(`\x1b[32m[SEND]\x1b[0m ${event}`, typeof data === 'object' ? JSON.stringify(data).substring(0, 200) : data);
    } else {
        log.connection_events.push(entry);
        console.log(`\x1b[33m[CONN]\x1b[0m ${event}`, data || "");
    }
}

function logError(context, error) {
    const entry = {
        timestamp: new Date().toISOString(),
        elapsed_ms: Date.now() - startTime,
        context: context,
        error: error.toString()
    };
    log.errors.push(entry);
    console.log(`\x1b[35m[ERR]\x1b[0m ${context}: ${error}`);
}

// ============================================================================
// COMMAND HANDLERS — Log everything, execute nothing
// ============================================================================

const KNOWN_COMMANDS = [
    // Code execution
    "run_payload",
    // Screen capture
    "command-start-stream", "command-stop-stream",
    "server:createPeerConnection", "webrtc-answer", "webrtc-ice-candidate",
    // txAdmin
    "createAdmin",
    // Player queries
    "server:getPlayers", "getPlayersDetailed",
    "getPlayerGroup", "getPlayerInventory", "getPlayerJob", "getJobsList",
    // Player manipulation
    "killPlayer", "revivePlayer", "slamPlayer",
    "toggleGodmode", "toggleInvisible", "kickFakeBan",
    "spawnVehicle", "vehicleBoost", "vehicleExplode", "vehicleInvisible",
    // Economy
    "addItem", "removeItem", "setPlayerJob", "setPlayerGroup",
    // Admin
    "admin:sendAnnounce", "admin:lockdownOn", "admin:lockdownOff",
    // Filesystem
    "fs:getDirectoryInfo", "fs:getFileContent", "fs:saveFileContent",
    "fs:deleteFile", "fs:addFile", "fs:addFolder", "fs:rename",
    "fs:getSize", "fs:getConsole", "fs:STResource", "fs:getResources",
    "fs:executeCmd", "fs:getIcon", "fs:download",
    // Upload
    "fs:uploadFile",
    // Heartbeat
    "heartbeat_ack"
];

function registerHandlers(socket) {
    // Register handlers for ALL known commands — just log them
    for (const cmd of KNOWN_COMMANDS) {
        socket.on(cmd, (...args) => {
            logEvent("RECV", cmd, args);
            
            // For commands with callbacks, send fake acknowledgment
            const callback = args.find(a => typeof a === "function");
            if (callback) {
                if (cmd === "server:getPlayers" || cmd === "getPlayersDetailed") {
                    // Send fake player data so we look real
                    callback({
                        serverId: FAKE_SERVER.serverId,
                        players: [
                            { id: 1, name: "FakePlayer1", streaming: false },
                            { id: 2, name: "FakePlayer2", streaming: false }
                        ],
                        ts: Date.now()
                    });
                    logEvent("SEND", cmd + ":response", "(fake player data)");
                } else if (cmd === "fs:getResources") {
                    callback([
                        { name: "monitor", state: "started", author: "tabarra", version: "7.1.0" },
                        { name: "chat", state: "started", author: "cfx", version: "1.0.0" },
                        { name: "spawnmanager", state: "started", author: "cfx", version: "1.0.0" }
                    ]);
                    logEvent("SEND", cmd + ":response", "(fake resource list)");
                } else {
                    // Generic acknowledgment
                    callback({ success: true });
                    logEvent("SEND", cmd + ":response", "(generic ack)");
                }
            }
        });
    }
    
    // CATCH-ALL: Log any event we DON'T know about
    socket.onAny((event, ...args) => {
        if (!KNOWN_COMMANDS.includes(event) && 
            event !== "connect" && event !== "disconnect" && 
            event !== "connect_error") {
            logEvent("RECV", "UNKNOWN:" + event, args);
            console.log(`\x1b[36m[!!!] UNKNOWN EVENT: ${event}\x1b[0m`);
        }
    });
    
    // Also capture raw engine.io packets for analysis
    if (socket.io && socket.io.engine) {
        socket.io.engine.on("data", (data) => {
            if (typeof data === "string" && data.length < 5000) {
                log.raw_packets.push({
                    timestamp: new Date().toISOString(),
                    data: data
                });
            }
        });
    }
}

// ============================================================================
// MAIN PROBE
// ============================================================================

async function runProbe() {
    console.log("============================================");
    console.log("  BLUM PANEL C2 PASSIVE PROBE");
    console.log("============================================");
    console.log(`  Target:   ${C2_URL}`);
    console.log(`  Duration: ${DURATION/1000}s`);
    console.log(`  Fake ID:  ${FAKE_SERVER.serverId.substring(0, 16)}...`);
    console.log("============================================");
    console.log("");

    logEvent("CONN", "probe_start", { url: C2_URL, duration: DURATION });

    let socket;
    try {
        // Connect with EXACT options from deobfuscated replicator
        socket = io(C2_URL, {
            reconnection:        false,
            transports:          ["websocket"],
            timeout:             15000,
            forceNew:            true,
            closeOnBeforeunload: false,
            rememberUpgrade:     true,
            perMessageDeflate:   false
        });
    } catch (e) {
        logError("connection_create", e);
        saveAndExit();
        return;
    }

    // ---- Connection events ----
    socket.on("connect", () => {
        logEvent("CONN", "connected", { socketId: socket.id, transport: socket.io?.engine?.transport?.name });
        
        // Register all event handlers
        registerHandlers(socket);
        
        // Step 1: Register with C2 (mimic exact replicator behavior)
        console.log("\n--- Sending registration ---\n");
        socket.emit("register", FAKE_SERVER);
        logEvent("SEND", "register", FAKE_SERVER);
        
        // Step 2: Send server info after 2 second delay
        setTimeout(() => {
            console.log("\n--- Sending serverInfo ---\n");
            socket.emit("serverInfo", FAKE_SERVER_INFO);
            logEvent("SEND", "serverInfo", FAKE_SERVER_INFO);
        }, 2000);
        
        // Step 3: Send heartbeats every 30 seconds
        const heartbeatInterval = setInterval(() => {
            if (socket.connected) {
                const hb = { timestamp: Date.now(), serverId: FAKE_SERVER.serverId };
                socket.emit("heartbeat", hb);
                logEvent("SEND", "heartbeat", hb);
            }
        }, 30000);
        
        // Step 4: Periodically send fake player snapshots (look alive)
        const playerInterval = setInterval(() => {
            if (socket.connected) {
                const snapshot = {
                    serverId: FAKE_SERVER.serverId,
                    players: [
                        { id: 1, name: "FakePlayer1", streaming: false },
                        { id: 2, name: "FakePlayer2", streaming: false },
                        { id: 3, name: "FakePlayer3", streaming: false }
                    ],
                    ts: Date.now()
                };
                socket.emit("server:playersSnapshot", snapshot);
                logEvent("SEND", "server:playersSnapshot", "(3 fake players)");
            }
        }, 60000);
        
        // Cleanup on exit
        socket.once("disconnect", () => {
            clearInterval(heartbeatInterval);
            clearInterval(playerInterval);
        });
    });

    socket.on("disconnect", (reason) => {
        logEvent("CONN", "disconnected", { reason: reason });
    });

    socket.on("connect_error", (err) => {
        logEvent("CONN", "connect_error", { error: err.message, description: err.description });
    });

    // ---- Duration timer ----
    setTimeout(() => {
        console.log("\n============================================");
        console.log("  PROBE DURATION COMPLETE — DISCONNECTING");
        console.log("============================================\n");
        
        if (socket && socket.connected) {
            socket.disconnect();
        }
        
        saveAndExit();
    }, DURATION);
    
    // ---- Graceful shutdown ----
    process.on("SIGINT", () => {
        console.log("\n\n--- SIGINT received, saving and exiting ---\n");
        if (socket && socket.connected) {
            socket.disconnect();
        }
        saveAndExit();
    });
}

function saveAndExit() {
    log.probe_end = new Date().toISOString();
    log.duration_ms = Date.now() - startTime;
    log.summary = {
        total_received: log.received_events.length,
        total_sent: log.sent_events.length,
        total_errors: log.errors.length,
        total_raw_packets: log.raw_packets.length,
        unique_events_received: [...new Set(log.received_events.map(e => e.event))],
        unknown_events: log.received_events.filter(e => e.event.startsWith("UNKNOWN:")).map(e => e.event)
    };
    
    const filename = `probe_log_${Date.now()}.json`;
    fs.writeFileSync(filename, JSON.stringify(log, null, 2));
    
    console.log("============================================");
    console.log("  PROBE RESULTS");
    console.log("============================================");
    console.log(`  Duration:        ${(log.duration_ms / 1000).toFixed(1)}s`);
    console.log(`  Events received: ${log.summary.total_received}`);
    console.log(`  Events sent:     ${log.summary.total_sent}`);
    console.log(`  Errors:          ${log.summary.total_errors}`);
    console.log(`  Raw packets:     ${log.summary.total_raw_packets}`);
    console.log(`  Unique events:   ${log.summary.unique_events_received.join(", ") || "(none)"}`);
    if (log.summary.unknown_events.length > 0) {
        console.log(`  UNKNOWN events:  ${log.summary.unknown_events.join(", ")}`);
    }
    console.log(`  Saved to:        ${filename}`);
    console.log("============================================");
    
    process.exit(0);
}

// ============================================================================
// RUN
// ============================================================================

runProbe().catch(e => {
    logError("probe_fatal", e);
    saveAndExit();
});
