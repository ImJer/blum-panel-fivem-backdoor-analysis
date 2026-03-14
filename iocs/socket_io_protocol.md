# Blum Panel Socket.IO Protocol — Complete Specification

## C2 Server: wss://fivems.lt
## Panel Frontend: wss://blum-panel.me, wss://warden-panel.me

---

## IMPLANT → C2 (13 event types)

| Event | Payload | Trigger |
|-------|---------|---------|
| `register` | `{serverId, apiKey, ip, servername, license, isPersonalPC, resourcename, monitorAppendResult}` | On first connect |
| `heartbeat` | `{timestamp, serverId}` | Every ~30 seconds |
| `serverInfo` | `{apiKey, serverId, servername, username, ip, playercount, maxcount, osEnvironment, license, framework, isPersonalPC, serverUptime, locale, anticheats}` | After registration |
| `server:playersSnapshot` | `{serverId, players: [{id, name, streaming}], ts}` | Periodic |
| `adminCreated` | `{success, password, host, token, username, discordID, error}` | After txAdmin credential theft |
| `groupData` | `{playerId, groupData \| error}` | Response to getPlayerGroup |
| `inventoryData` | `{playerId, inventory \| error}` | Response to getPlayerInventory |
| `jobData` | `{playerId, jobData \| error}` | Response to getPlayerJob |
| `jobsListData` | `{jobsList \| error}` | Response to getJobsList |
| `fs:uploadFile` | `{fileName, folderName, serverId, fileBuffer}` | Resource theft (base64 ZIP) |
| `fs:<cmd>:response:<reqId>` | `{result \| error}` | Response to filesystem commands |
| `server:webrtcIce` | `{serverId, playerId, viewerSocketId, candidate}` | WebRTC signaling |
| `server:webrtcOffer` | `{serverId, playerId, viewerSocketId, offer}` | WebRTC signaling |

## C2 → IMPLANT (39 command handlers)

### Code Execution
| Command | Payload | Action |
|---------|---------|--------|
| `run_payload` | `{code}` | If starts with "// javascript": `new Function(code)()`. Else: Lua via `onServerResourceFail` |

### Screen Capture (WebRTC)
| Command | Payload | Action |
|---------|---------|--------|
| `command-start-stream` | `{playerId, viewerSocketId}` | Start screen capture on player |
| `command-stop-stream` | `{playerId, viewerSocketId}` | Stop screen capture |
| `server:createPeerConnection` | `{data}` | WebRTC peer setup relay |
| `webrtc-answer` | `{playerId, viewerSocketId, answer}` | Relay WebRTC answer to player |
| `webrtc-ice-candidate` | `{playerId, viewerSocketId, candidate}` | Relay ICE candidate |

### txAdmin Exploitation
| Command | Payload | Action |
|---------|---------|--------|
| `createAdmin` | `{username, discordID}` | Create backdoor txAdmin admin via stolen token |

### Player Data Queries
| Command | Payload | Action |
|---------|---------|--------|
| `server:getPlayers` | `{}` | Returns player snapshot |
| `getPlayersDetailed` | `{serverId}` | Returns full player data (id, name, ip, identifiers, discord) |
| `getPlayerGroup` | `{playerId}` | QBCore/ESX/vRP group extraction |
| `getPlayerInventory` | `{playerId}` | QBCore/ESX/OxCore inventory |
| `getPlayerJob` | `{playerId}` | Job, grade, label |
| `getJobsList` | `{}` | All available jobs from framework |

### Player Manipulation
| Command | Payload | Action |
|---------|---------|--------|
| `killPlayer` | `{playerId}` | `SetEntityHealth(ped, 0)` |
| `revivePlayer` | `{playerId}` | Resurrect + heal to 200 |
| `slamPlayer` | `{playerId}` | `ApplyForceToEntity` 120 units upward |
| `toggleGodmode` | `{playerId, state}` | `SetEntityInvincible` |
| `toggleInvisible` | `{playerId, state}` | `SetEntityVisible` |
| `kickFakeBan` | `{playerId}` | `DropPlayer` with fake ban message |
| `spawnVehicle` | `{playerId, model}` | Create vehicle, put player in it |
| `vehicleBoost` | `{playerId, state}` | Turbo + 100x power + 500 max speed |
| `vehicleExplode` | `{playerId}` | Explosion + destroy engine + lock doors |
| `vehicleInvisible` | `{playerId, state}` | Toggle vehicle visibility |

### Economy Manipulation
| Command | Payload | Action |
|---------|---------|--------|
| `addItem` | `{playerId, item, amount}` | QBCore/ESX add inventory item |
| `removeItem` | `{playerId, item, amount}` | QBCore/ESX remove item |
| `setPlayerJob` | `{playerId, job, grade}` | Set job via framework |
| `setPlayerGroup` | `{playerId, group, level}` | Set permissions |

### Server Administration
| Command | Payload | Action |
|---------|---------|--------|
| `admin:sendAnnounce` | `{message}` | Broadcast with author "blum-panel.me" |
| `admin:lockdownOn` | `{reason}` | Kick ALL players, block ALL connections |
| `admin:lockdownOff` | `{}` | Set flag false (but blocker stays until restart) |

### Filesystem Access
| Command | Payload | Action |
|---------|---------|--------|
| `fs:getDirectoryInfo` | `{dir}` | Directory listing |
| `fs:getFileContent` | `{path}` | Read file |
| `fs:saveFileContent` | `{path, content}` | Write file |
| `fs:deleteFile` | `{path}` | Delete file |
| `fs:addFile` | `{dir, file}` | Create file |
| `fs:addFolder` | `{dir, name}` | Create directory |
| `fs:rename` | `{oldPath, newName}` | Rename |
| `fs:getSize` | `{dir}` | Get size in bytes |
| `fs:getConsole` | `{serverId}` | Last 500 console lines |
| `fs:STResource` | `{action, name}` | Start/stop resource |
| `fs:getResources` | `{serverId}` | All resources with metadata |
| `fs:executeCmd` | `{command}` | Console command via RCE |
| `fs:getIcon` | `{filePath}` | Read file as base64 |
| `fs:download` | `{directory, folderName, serverId}` | Deploy resource from C2 with dropper injection |

### Heartbeat
| Event | Payload | Action |
|-------|---------|--------|
| `heartbeat_ack` | `(none)` | C2 acknowledges heartbeat |

## PANEL FRONTEND → C2 (additional events from dashboard)

| Event | Purpose |
|-------|---------|
| `joinServerRoom` | Select a server to control |
| `leaveServerRoom` | Deselect server |
| `getServerInfo` | Get server details |
| `requestPlayersDetailed` | Get full player list |
| `query-player-info` | Get specific player info |
| `watch-player` | Start surveillance of player |
| `stop-watch` | Stop surveillance |
| `fs:startConsoleStream` | Live console streaming |
| `fs:stopConsoleStream` | Stop console stream |
| `admin:executeCmd` | Execute console command |
| `admin:runPayload` | Execute code |
| `admin:getToken` | Steal txAdmin token |
| `admin:getDiscordProfile` | Get victim's Discord info |

## DISCORD BOT MODULE (24 commands)

| Event | Purpose |
|-------|---------|
| `discord:connect` | Connect bot to Discord server |
| `discord:disconnect` | Disconnect bot |
| `discord:getServers` | List Discord servers |
| `discord:getChannels` | List channels |
| `discord:getMembers` | List members |
| `discord:getWebhooks` | List webhooks |
| `discord:banMember` | Ban user |
| `discord:kickMember` | Kick user |
| `discord:timeoutMember` | Timeout user |
| `discord:changeNickname` | Change nickname |
| `discord:sendMessage` | Send message |
| `discord:createChannel` | Create channel |
| `discord:createRole` | Create role |
| `discord:createInvite` | Create invite |
| `discord:createAllWebhooks` | Mass create webhooks |
| `discord:sendViaWebhooks` | Send via webhooks |

## Socket.IO Connection Options (implant side)

```javascript
{
    reconnection: false,
    transports: ["websocket"],
    timeout: 15000,
    forceNew: true,
    closeOnBeforeunload: false,
    rememberUpgrade: true,
    perMessageDeflate: false
}
```

## Reconnect: Exponential backoff 2000 * 1.5^attempts, capped at 60000ms, ±25% jitter
