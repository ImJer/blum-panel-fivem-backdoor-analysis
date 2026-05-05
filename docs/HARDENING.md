# Hardening Playbook — Defense in Depth for FiveM Operators

Detection is reactive. Hardening is proactive. The Blum / Warden / Cipher / GFX Panel family will rotate IOCs, change file names, register new domains, and ship new payloads. Static signature detection is a cat-and-mouse game we cannot win on its own.

What we *can* do is make our servers genuinely hostile to whatever the family ships next, by stacking layered defenses that don't depend on us recognising the specific malware. This document is a layered playbook — pick whichever layers your environment can support, and stack as many as you can.

The further down you can get, the more the attacker has to work to compromise you. Even the first three layers eliminate most casual attacks.

---

## Threat model in one paragraph

A malicious FiveM resource gets installed (operator pulls it from a leak forum, gets it from a "free script" Discord, or someone with txAdmin admin rights deploys it). Once running, it has the privileges of the FXServer process — file system, network, and any creds reachable from that user. It tries to phone home to a C2, drop additional payloads, register backdoor net events, and persist. Hardening cuts off as many of those steps as possible regardless of what the specific malware looks like.

---

## Layer 1 — Run FXServer as a non-admin / dedicated user

The single highest-leverage hardening step. The blast radius of any FiveM compromise is bounded by the privileges of the user that runs FXServer. See [`docs/BLAST_RADIUS.md`](BLAST_RADIUS.md) for the full breakdown.

### Windows

- Create a dedicated local user (e.g. `fxsvc`) with **Standard User** rights, **never** Administrator.
- Install FXServer to a path the `fxsvc` user can read but only write to specific subdirectories (artefact dir + `server-data`).
- Run FXServer as `fxsvc` via `Run as different user`, a scheduled task with the dedicated user, or a Windows service running as `fxsvc`.
- **Do not** sign in to the `fxsvc` user with browsers, Discord, Steam, or any personal account. The DPAPI vulnerability described in `BLAST_RADIUS.md` applies per user; if `fxsvc` never has any browser session or saved password, the worst-case credential-theft scope is empty.

### Linux

- Create a dedicated `fxsvc` system user with no shell login (`useradd -r -s /usr/sbin/nologin fxsvc`).
- Install FXServer under `/opt/fivem/`, owned by `fxsvc:fxsvc`.
- Run FXServer via systemd, with `User=fxsvc` and `Group=fxsvc`.
- Add hardening directives to the unit file:
  ```ini
  [Service]
  User=fxsvc
  Group=fxsvc
  NoNewPrivileges=true
  ProtectSystem=strict
  ProtectHome=true
  PrivateTmp=true
  ReadWritePaths=/opt/fivem/server-data /var/log/fivem
  RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
  RestrictNamespaces=true
  RestrictRealtime=true
  LockPersonality=true
  MemoryDenyWriteExecute=true
  CapabilityBoundingSet=
  AmbientCapabilities=
  ```
- These directives prevent FXServer from getting `setuid`, mounting filesystems, escalating, or writing to anywhere outside the server-data path even if the malware has full code execution as `fxsvc`.

---

## Layer 2 — File-system permissions and read-only artefacts

Runtime malware re-writes resource files. If the resource directory is read-only at the OS level *while the server is running*, that motion fails.

### Linux

- Once you've installed and configured a resource, make its directory read-only for the FXServer user:
  ```bash
  sudo chown -R root:fxsvc /opt/fivem/server-data/resources/[resource_name]
  sudo chmod -R u+rwX,g+rX,o-rwx /opt/fivem/server-data/resources/[resource_name]
  ```
- This means installing a new resource or updating an existing one requires explicit `sudo`, which is what you want.
- Trade-off: live txAdmin "Refresh resources" + edit-on-disk workflows become friction. You're trading developer ergonomics for runtime integrity.

### Windows

- Set NTFS ACLs on the `resources/` directory: grant `fxsvc` read+execute, deny write.
- Reserve write access for an `Administrator` account that you only use to install/update resources.

### Read-only `monitor/`

The `monitor/` (txAdmin) directory should *never* be written to at runtime. Set it explicitly read-only for the FXServer user, regardless of how you handle the rest. The runtime trap (`dropper_trap/`) does this in software; OS-level enforcement is belt-and-suspenders.

---

## Layer 3 — Egress firewall (allowlist-only)

The most durable network defense. If FXServer can only reach known-good destinations, it doesn't matter what new C2 domain Blum registers next month — the connection fails before it even resolves DNS.

### What FXServer legitimately needs

- `*.cfx.re` and `*.fivem.net` — Cfx.re infrastructure (license validation, server list, asset CDN)
- Your database server (whatever IP / hostname it is)
- Your Discord webhook URLs (for legitimate in-game webhooks; use a fixed list)
- Optionally `discord.com` and `discordapp.com` if you use rich-presence integration
- Time servers (NTP) — usually fine to allow
- Steam Web API endpoints — only if you use Steam identifier checks

### What FXServer should NEVER need

- Random `.com`, `.net`, `.lt`, `.org`, `.club`, `.xyz`, `.me` domains
- Newly-registered short-name domains (every Blum domain matches this)
- Unrelated CDNs (Cloudflare Workers `*.workers.dev`, free TLS certificate hosts, paste sites)
- Direct-to-IP HTTP/HTTPS to anywhere not on your allowlist

### Windows — Defender Firewall

Outbound rules in the `Blum Panel C2 Block` group already exist (created by `detection/blum_windows.ps1 -Action Block -Apply`). To go from blocklist to allowlist:

```powershell
# DENY all outbound from FXServer.exe
New-NetFirewallRule -DisplayName "FXServer egress (default deny)" `
    -Direction Outbound -Action Block -Program "C:\FXServer\FXServer.exe" `
    -Profile Any -Enabled True

# Then explicitly ALLOW each legitimate destination:
New-NetFirewallRule -DisplayName "FXServer -> Cfx.re" `
    -Direction Outbound -Action Allow -Program "C:\FXServer\FXServer.exe" `
    -RemoteAddress "Any" -RemotePort 443 -Protocol TCP `
    -Description "Cfx.re infrastructure" -Profile Any -Enabled True
# Repeat for each allowed destination
```

The block rule must run *after* the allow rules in priority for the allowlist to function — Windows Firewall evaluates Allow before Block by default within the same priority. To enforce default-deny behaviour, see [Microsoft's WFP filter weight documentation](https://learn.microsoft.com/en-us/windows/win32/fwp/filter-weight-assignment).

### Linux — `iptables` egress allowlist

```bash
# 1. Allow established/related outbound (returning traffic)
sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 2. Allow specific outbound destinations from the fxsvc user
sudo iptables -A OUTPUT -m owner --uid-owner fxsvc -d cfx.re -p tcp --dport 443 -j ACCEPT
sudo iptables -A OUTPUT -m owner --uid-owner fxsvc -d <DB_IP> -p tcp --dport 3306 -j ACCEPT
sudo iptables -A OUTPUT -m owner --uid-owner fxsvc -d 1.1.1.1 -p udp --dport 53 -j ACCEPT  # DNS

# 3. DENY everything else from fxsvc
sudo iptables -A OUTPUT -m owner --uid-owner fxsvc -j REJECT --reject-with tcp-reset
```

The `--uid-owner` match ties the rule to a specific user — only outbound traffic *from FXServer* (running as `fxsvc`) is filtered. Other users on the box (yourself, Pterodactyl wings, etc.) are unaffected.

### Cloudflare Tunnel as a forwarder

If your FXServer needs to reach external services (database hosted elsewhere, S3, etc.) and you don't want to maintain firewall rules, a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/) with named-host allowlist gives you a single point of egress policy. FXServer connects to the tunnel; the tunnel allows only specified destinations.

---

## Layer 4 — Containerization

The FXServer process is process-level untrusted. Containerize it.

### Pterodactyl on Linux (gold standard)

- The default Pterodactyl Docker container is non-privileged, network-namespaced, and has no access to the host filesystem outside the bind mount.
- Make sure `--privileged` is NOT set (default is fine).
- Avoid `-v /:/host` or `-v /var/run/docker.sock:/var/run/docker.sock` bind mounts at all costs.
- Configure the Pterodactyl egress allowlist for the egg if you can.

### Docker on Windows or Linux directly

If you don't run Pterodactyl, run FXServer in a vanilla Docker container:

```bash
docker run --rm \
    --name fxserver \
    --read-only \
    --tmpfs /tmp:exec \
    --user 65534:65534 \
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    --network fxserver-net \
    -v /opt/fivem/server-data:/server-data \
    -p 30120:30120/tcp -p 30120:30120/udp \
    fxserver-image
```

The `--read-only` flag makes the entire container filesystem read-only except the explicitly-mounted writable volume; `--cap-drop=ALL` removes all Linux capabilities; `--user 65534:65534` runs as nobody. Even with full code execution inside the container, the malware has nowhere to write outside `/server-data`.

### Windows Server Containers

Available on Windows Server 2019+, but less mature than Linux containers. If you can use Linux + Docker for FiveM, do — the security primitives are more battle-tested.

---

## Layer 5 — Runtime trap (`dropper_trap/`)

Always-on, not just for post-incident. The trap is a FiveM resource that hooks the server-side Lua and JS runtimes to block dropper behaviour at the moment it tries to execute.

### What it blocks unconditionally

- Every `os.execute` call (Lua) — there is no legitimate reason for FiveM resources to run shell commands.
- Every `io.popen` call (Lua) — same reasoning.
- Every write to `monitor/resource/cl_playerlist.lua`, `sv_main.lua`, `sv_resources.lua` from any resource other than `monitor` itself — txAdmin tampering attempts caught regardless of payload content.
- Every `RegisterNetEvent` for known backdoor event names (`onServerResourceFail`, `txadmin:js_create`, etc.) — the trap shadows them so the malicious handler is preempted.
- Every HTTPS request from the FXServer JS context to a known C2 domain.

### Deploying it

1. Copy the `dropper_trap/` directory to your `resources/` folder.
2. Add `ensure dropper_trap` to your `resources.cfg` — **as the very first `ensure` line.** FiveM loads resources in `resources.cfg` order; if `dropper_trap` loads after a malicious resource, the malicious handler registers first and runs before the trap can preempt it. To guarantee load order even if other config tools reorder things, you can rename the resource folder to `aaa_dropper_trap` so it sorts alphabetically first.
3. Restart the server. The trap prints `[TRAP] v3 ACTIVE` and `[TRAP-JS] v3 ACTIVE` to the console at startup; these confirm both halves loaded.
4. Watch the console for `[TRAP] BLOCKED ...` lines — they tell you the trap caught something.

### What it doesn't catch

- Compiled / pre-evaluated payloads that have already executed before the trap loaded (mitigation: load it first; see step 2).
- Malware that uses execution paths the trap doesn't hook (mitigation: stack with the other layers in this doc — the trap is one layer, not the whole defense).
- Threats that don't match any known pattern *and* don't trigger any behavioral hook (mitigation: layer 6).

---

## Layer 6 — Resource integrity baseline

Catch *any* resource modification, regardless of content. The Blum family has rotated marker strings before. A clean SHA256 baseline of every `.lua` and `.js` under `resources/`, taken right after a known-clean install, lets you detect *any* drift on subsequent comparisons.

### Take the baseline

Linux:
```bash
detection/baseline.sh /path/to/server-data > baseline-$(date +%Y%m%d).json
```

Windows:
```powershell
.\detection\blum_windows.ps1 -Action Baseline -Path C:\FXServer\server-data -OutputDir .
```

### Compare on demand

Linux:
```bash
detection/compare.sh /path/to/server-data baseline-20260505.json
```

Windows:
```powershell
.\detection\blum_windows.ps1 -Action Compare -Path C:\FXServer\server-data -BaselineFile .\baseline-20260505.json
```

The compare action reports modified, added, and removed files vs. the baseline. Any drift on a file you didn't intentionally change is suspicious — review it.

### Re-baseline after intentional changes

When you legitimately update a resource, take a new baseline. Old baselines become reference points for "where was this file at version N?", not active monitors after that.

---

## Layer 7 — Defender / EDR rules (Windows)

Windows Defender on a properly-configured Server 2019+ install is reasonably effective against generic malware. Some recommendations to make it sharper for FiveM:

- **Do not exclude FXServer or `server-data` from Defender scanning.** Attackers add Defender exclusions for these paths as a persistence step (we audit for this in `blum_windows.ps1 -Action Audit`). Legitimate operators should never need this exclusion.
- **Enable controlled folder access** for `monitor/` and any directory containing operator credentials (`txData/`, `server.cfg`). Defender will block any process not on the allowlist from writing to those directories.
- **Enable Attack Surface Reduction (ASR) rules**, particularly:
  - "Block executable files from running unless they meet a prevalence, age, or trusted list criterion"
  - "Block process creations originating from PSExec and WMI commands"
  - "Block credential stealing from the Windows local security authority subsystem (lsass.exe)"
- **Enable PowerShell Script Block Logging** (`Group Policy: Computer Configuration -> Administrative Templates -> Windows PowerShell -> Turn on Script Block Logging`). Logs every PowerShell script run on the box; useful for forensics post-incident.

---

## Layer 8 — Code review every new resource

This is the layer that's hardest to enforce but cheapest to implement. Most Blum infections start with an operator pulling a "free admin menu" or "leaked car pack" from a Discord. Every single one of those is a vector.

The simple rule:

> If a resource is not from a source you trust as much as you trust your hosting provider, **read its `fxmanifest.lua`, every `.lua`, and every `.js` end to end** before adding it to your `resources.cfg`.

What to look for:

- `os.execute`, `io.popen`, `io.open` with attacker-controlled paths — almost no legitimate resource needs these.
- `load(`, `loadstring(`, `RunString(` — same; if present, follow the data flow to verify the input is trusted.
- HTTP/HTTPS requests to anything that isn't the obvious legitimate endpoint (e.g. a player count display might call your own API; it should not call `9ns1.com`).
- `RegisterNetEvent` with handlers that take arbitrary strings/tables and pass them to `load()` / `pcall(load(...))` — that's the dropper RCE pattern.
- Heavy obfuscation. JScrambler / Luraph / similar in a script that markets itself as "open source" is a red flag in itself; legitimate scripts publish readable code.
- `fxmanifest.lua` paths under `node_modules/.cache/`, `dist/`, `middleware/` — these are characteristic Blum injection sites.
- Files larger than ~30KB that consist primarily of one giant Lua/JS string — likely an obfuscated dropper.

If you don't have time to read it, you don't have time to install it.

---

## Layer 9 — Operator credential hygiene

Independent of the server itself.

- **Never sign in to anything personal from the same Windows user that runs FXServer.** If your "FiveM workstation" is also where you check Discord, manage Cloudflare, RDP into other servers, or use a browser at all, the DPAPI exposure makes a single FXServer infection a credential theft event for *every* account in your browser. See `BLAST_RADIUS.md`.
- **Use hardware MFA** (YubiKey, Titan, etc.) for every high-value account. Browser-extension TOTP authenticators are decryptable along with the rest of the user's DPAPI store; hardware keys are not.
- **Rotate the txAdmin master password** quarterly even when not under attack.
- **Audit `admins.json`** monthly. The dropper may add an admin under a name that looks innocuous; reviewing the list periodically catches that.
- **Use unique passwords across every service**, with a password manager. The Blum theft payload exfiltrates `txData/admins.json` — if your txAdmin password is reused for your hosting panel, your hosting panel is also compromised.

---

## Layer 10 — Monitoring and response readiness

Hardening reduces the chance of compromise; it doesn't eliminate it. Be ready to detect.

- Run `detection/blum_windows.ps1 -Action All -Path ... -OutputDir ...` (Windows) or `detection/scan.sh` (Linux) on a schedule — weekly is reasonable for a low-touch server, daily for a busier one.
- Review the trap's blocked-event logs. The trap prints to the FiveM console; pipe console logs to a log aggregator if you have one.
- Set up alerts on outbound firewall blocks. If the egress allowlist is in place, every block is interesting.
- Maintain a current baseline (Layer 6). Compare on demand if anything looks weird.
- Read `BLAST_RADIUS.md` *before* you need it. Operators making decisions during an active incident under pressure make worse decisions than operators who pre-decided.

---

## TL;DR

If you can only do three things, do these:

1. **Run FXServer as a non-admin / dedicated user** with no personal browser sessions. Closes the DPAPI credential-theft path.
2. **Deploy `dropper_trap/`** as the first `ensure` line in `resources.cfg`. Behavioral block of `os.execute`, `io.popen`, txAdmin file tampering, and known C2 traffic regardless of marker rotation.
3. **Egress allowlist FXServer.** Cuts off C2 access for every Blum domain past, present, and future.

Stack the rest as your operational tolerance allows. Every additional layer raises the cost of compromise.

---

## See also

- [`docs/BLAST_RADIUS.md`](BLAST_RADIUS.md) — what to do *after* an infection: scope-of-compromise matrix, per-environment action checklists, credential-rotation reference card
- [`docs/TXADMIN_TAMPERING.md`](TXADMIN_TAMPERING.md) — five txAdmin tampering points walkthrough with code snippets and the recommended reinstall procedure
- [`iocs/blum_iocs.json`](../iocs/blum_iocs.json) — canonical IOC inventory consumed by every scanner and runtime trap in this repo
- [`detection/blum_windows.ps1`](../detection/blum_windows.ps1) — Windows tooling (Scan / Audit / Forensics / Block / Remediate / Baseline / Compare)
- [`detection/scan.sh`](../detection/scan.sh), [`detection/block_c2.sh`](../detection/block_c2.sh) — Linux scanner and C2 blocker
- [`dropper_trap/`](../dropper_trap) — FiveM-side runtime trap
