# Blast Radius — Scope of Compromise by Environment

**If your scanner reported high-confidence indicators, read this before deciding what to clean and what to rotate.**

The Blum / Warden / Cipher / GFX Panel backdoor delivers JavaScript and Lua payloads that run with the **full code-execution rights of the FXServer process**. Lua's `os.execute`, `io.popen`, and `io.open`, and the JavaScript `child_process` and `fs` modules in citizen-server runtime, all give the attacker shell-level access as whatever user launched FXServer. The blast radius is not "the FiveM server" — it's "everything that user can read or run."

What that user can read or run depends entirely on **where FXServer was running**. A scrub that's complete for a Docker container is wildly insufficient for a Windows host running FXServer directly. A scrub on a Windows admin install is insufficient even after a full credential rotation, because the OS itself can no longer be trusted.

This document spells out the scope by environment so operators can stop guessing.

---

## TL;DR matrix

| Environment | Blast radius | Files alone enough? | Minimum response |
|-------------|--------------|---------------------|------------------|
| **Pterodactyl / Docker container on Linux** | The container | Yes, if non-privileged | Scrub resources + rotate FiveM creds, redeploy from a clean image |
| **Linux host (no Docker)** | The user that ran FXServer (root if it ran as root) | Sometimes | Above + audit cron / systemd / `.bashrc` / `.ssh` for the user. Reinstall OS if the user was root. |
| **Windows host, non-admin user** | The whole user profile, including every browser-saved credential and session cookie (DPAPI is decryptable by any code running as that user) | **No** | Above + force-logout-everywhere on every account ever signed into a browser as that user, rotate every saved password, delete and recreate the Windows user |
| **Windows host, Administrator** | The whole OS (SYSTEM access, kernel drivers, LSASS, Defender exclusions, all users) | **No** | **Reinstall Windows from clean media.** No "clean it in place" option exists. |
| **Windows host that you also use as a workstation** (RDP browse / Discord / personal accounts) | Everything you have ever signed into on that machine | **No** | All of the above + treat every credential ever entered on that machine as exfiltrated. Force-logout-everywhere globally. |

If you're not sure which row you're on, read the matching section below before you start.

---

## Pterodactyl / Docker container on Linux

This is the lowest-blast-radius case and the one the upstream investigation was scoped against. The malware can do real damage but is contained to the container's process namespace, file system, and network identity.

### What's compromised
- Everything readable inside the container's filesystem: `server.cfg`, `txData/admins.json`, the FiveM resources directory, any `.env` files, any creds passed in via environment variables.
- Any credential present in resource files: framework admin passwords (ESX, QBCore, vRP, vMenu), database connection strings, Discord webhook URLs and bot tokens used by resources, any third-party API keys (Cloudflare, registrar, custom panels).
- The Cfx.re license key (`sv_licenseKey` in `server.cfg`).
- The RCON token (`rcon_password` in `server.cfg`).
- Any Cfx.re forum auth artifacts txAdmin had cached.
- Anything in the container's `node_modules` cache or persistent volumes.
- Player data the server stored: Steam IDs, Discord IDs, license identifiers, in-game character data, any PII written into the database.

### What's almost certainly safe (vanilla container)
- The host OS, kernel, and other containers.
- Files outside the container's bind mounts and volumes.
- Other users on the same host.
- Other networks reachable by the host but not by the container.

### Caveats that widen the blast radius
- **Privileged containers** (`--privileged`, capability `SYS_ADMIN`, etc.) — the malware can break out of the namespace. Treat as a Linux non-Docker compromise.
- **Bind mounts to sensitive paths** (`/var/run/docker.sock`, `/`, the host's home directory, the host's `/etc`) — anything mounted in is part of the blast radius. Docker socket mount = full host takeover.
- **Shared networks** with management interfaces (Pterodactyl wings UI, Portainer, Traefik dashboards) reachable from the container without auth — the malware can attack those.
- **Containers running as root inside the container** with no `USER` directive and no user namespace remapping — slightly easier to escalate via kernel exploits, though still contained for a vanilla setup.

### Action checklist

```
[ ] Stop the container immediately.
[ ] Take a copy of txData/admins.json for evidence (you will need to audit who was an admin during compromise).
[ ] Rotate txAdmin master password.
[ ] Delete every txAdmin admin account that you do not personally recognise. JohnsUrUncle is the known backdoor account. There may be others.
[ ] Re-enrol every legitimate admin with new credentials.
[ ] Rotate rcon_password in server.cfg.
[ ] Regenerate sv_licenseKey from https://keymaster.fivem.net/ (revoke the old one).
[ ] Rotate every database user that the server uses to connect.
[ ] Rotate every Discord webhook URL referenced in any resource (the URLs are credentials).
[ ] Rotate every Discord bot token referenced in any resource.
[ ] Rotate framework-side admin credentials (ESX/QBCore/etc. admin password, vMenu permissions, etc.).
[ ] Restore the resources directory from a known-clean source: your VCS, a clean backup pre-dating the infection, or fresh installs of each resource from its official upstream.
[ ] Redeploy the container from a fresh FiveM image (do not start the existing image again).
[ ] Re-run detection/scan.sh against the new container to confirm it is clean.
[ ] Deploy dropper_trap/ as runtime protection.
```

If the container was privileged or had a sensitive bind mount, **stop here and read the next section** instead — your blast radius is bigger than the container.

---

## Linux host (FXServer running directly, no container)

The blast radius is the user account that ran FXServer. If that user was a dedicated `fivem` user with limited privileges, the situation is recoverable. If FXServer ran as root, the host is gone.

### What's compromised (in addition to the container case above)
- Every file in the FiveM user's home directory: shell history, SSH keys, dotfiles, anything the user ever wrote.
- Cron jobs (`crontab -l`) and user-scope systemd timers.
- `~/.bashrc`, `~/.profile`, `~/.zshrc`, `~/.bash_logout`, `~/.config/autostart/` — common persistence points.
- `~/.ssh/authorized_keys` — the attacker may have appended a public key.
- `~/.ssh/known_hosts` — useful for the attacker to know what other systems you connect to.
- Anything readable via the user's group memberships (audit `id`).
- Environment variables exported in shell rc files (database URLs, API keys, GitHub tokens that were `export`ed for convenience).
- If the user has `sudo` without password for any command, that command's privileges are compromised too.
- If the user is in the `docker` group, **the entire host is compromised** (docker group membership is root-equivalent).

### If FXServer was running as root

Stop. The OS is compromised. The remediation is "reinstall the OS from clean media." Continuing to use the same OS image after a root-level compromise leaves the attacker every persistence vector imaginable: kernel modules, modified initramfs, modified `/etc/sudoers`, modified PAM, modified SSH keys for every account, replaced binaries in `/usr/bin`. There is no scan that conclusively cleans a root-compromised Linux box.

### Action checklist (FXServer ran as a regular user)

```
[ ] Run all container-case actions above first.
[ ] crontab -l for the FiveM user; remove anything you didn't add.
[ ] systemctl --user list-units --type=service --type=timer; remove anything you didn't add.
[ ] cat ~/.bashrc ~/.profile ~/.zshrc ~/.bash_logout; remove any unfamiliar lines (especially trailing `curl ... | sh` or anything writing to ~/bin).
[ ] ls -la ~/.config/autostart/; remove unfamiliar entries.
[ ] cat ~/.ssh/authorized_keys; remove every key you do not personally recognise.
[ ] last -a -F | head -50; look for unfamiliar logins.
[ ] grep -i password ~/.bash_history (do this calmly, then rotate every password you find).
[ ] Audit env files (.env, .env.local) in the home directory; rotate every credential they contained.
[ ] Rotate the FiveM user's own password.
[ ] Rotate every SSH key the FiveM user owned that was reused on other systems.
[ ] Rotate any GitHub Personal Access Token that was on disk or in env vars.
[ ] If the user is in docker, sudo, or wheel groups, treat the host as fully compromised. Reinstall the OS.
```

---

## Windows host (FXServer.exe running directly) — non-admin user

This is where most operators get caught off-guard. "I ran FXServer as a regular user, so it's just like the Linux non-Docker case, right?" Not quite — Windows has a credential plumbing layer that Linux does not, and that layer is fully decryptable by any code running as the same user.

### Why DPAPI is the issue

Windows has an API called the Data Protection API (DPAPI). Chrome, Edge, Brave, Opera, Vivaldi, every Chromium browser, many .NET applications, RDP saved credentials (`mstsc /savedconfig`), Wi-Fi profiles, and Outlook PSTs all encrypt their secrets with DPAPI. DPAPI's encryption key is derived from the user's Windows password. When the user is logged in, any process running as that user can call `CryptUnprotectData` and DPAPI hands back the plaintext — no prompt, no consent, no UAC.

This means malware running as the FiveM user can read:
- **Every saved password** in Chrome, Edge, Brave, Opera, Vivaldi for that user (`%LOCALAPPDATA%\<browser>\User Data\Default\Login Data`).
- **Every cookie** in those browsers (`%LOCALAPPDATA%\<browser>\User Data\Default\Network\Cookies`). Session cookies are credential-equivalent for any site that doesn't require step-up auth.
- **Every saved Wi-Fi key** for the user.
- **Every saved RDP credential**.
- **Every credential in Windows Credential Manager** for the user vault.

Firefox doesn't use DPAPI but stores its password DB in the user's profile directory; it's also readable by malware as that user (encryption is keyed to a master password the user almost certainly doesn't have set).

### What's compromised (in addition to everything above)
- Every browser cookie jar and password store for that user, every browser profile.
- Discord desktop client token (`%APPDATA%\discord\Local Storage\leveldb\*.ldb`). The token is a credential-equivalent: anyone with the token can act as the Discord account without password or 2FA until the token is invalidated by a password change.
- Steam: the `ssfn*` files in `%PROGRAMFILES(x86)%\Steam\` are session keepers that bypass Steam Guard email confirmation. If exfiltrated, the attacker can sign in to your Steam account without triggering the email warning.
- Every game launcher and store account stored on this user (Epic, Riot, Battle.net, EA, Ubisoft, GOG).
- Every OAuth-issued token cached by every application installed under this user.
- Every locally-installed dev tool's cached credentials: GitHub CLI, GitLab CLI, AWS CLI, gcloud, Azure CLI, kubectl, Terraform — any of these may have stored creds in the user profile.
- Scheduled tasks in user scope (Task Scheduler, `\Users` task folders).
- HKCU registry hive (Run keys, Image File Execution Options for user-scope, Shell folders, Userinit).
- Startup folder: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`.

### What's still safe (non-admin case)
- The Windows OS itself (you still have the option to recover).
- Other Windows users' profiles.
- Anything requiring elevation: services, drivers, HKLM, LSASS dump, SYSTEM-protected files.
- BIOS / firmware / boot loader.
- BitLocker keys (stored encrypted with the SYSTEM DPAPI master key, not the user's).

### Action checklist

```
[ ] Run all earlier checklists (container case for FiveM creds; Linux non-Docker is not directly applicable but the FiveM portion is).
[ ] Revoke the Cfx.re license key via keymaster.fivem.net (regardless of whether you reissue immediately).
[ ] Force-logout-everywhere on every account ever signed into a browser by this Windows user. List of services to definitely cover:
        - Discord (account settings → Devices → log out of all)
        - GitHub (Settings → Sessions)
        - Microsoft (account.microsoft.com → Privacy → Recent activity → Sign me out everywhere)
        - Google (myaccount.google.com → Security → Your devices → Sign out)
        - Cloudflare (My Profile → Sign Out Everywhere)
        - Your hosting provider (Vultr/OVH/Hetzner/etc.)
        - Your domain registrar (Namecheap, Cloudflare Registrar, Porkbun, etc.)
        - Steam (account → Manage Steam Guard → deauthorize all other devices)
        - Every game launcher: Epic, Riot, Battle.net, EA, Ubisoft, GOG
        - Every email provider: Gmail, Outlook, ProtonMail, Tutanota
        - Banking and crypto exchanges (Coinbase, Binance, Kraken, etc.)
        - Password manager (1Password, Bitwarden, LastPass, KeePass) — and rotate the master password
        - Any SaaS dev tool: Vercel, Netlify, Supabase, AWS, GCP, Azure, Digital Ocean, Linode
        - Any social media: X/Twitter, Reddit, Mastodon, Bluesky
[ ] Rotate every password ever saved in any browser used by this user. Treat every saved password as known to the attacker.
[ ] Re-enrol every MFA factor where possible. TOTP secrets in browser-installed authenticators (Authy desktop, browser extensions) are compromised. Hardware keys (YubiKey) are not.
[ ] Rotate every API key for every service ever logged into via browser. The session cookie was enough to issue new API keys, so an old API key is not safe just because the password was rotated.
[ ] Change Discord password. This invalidates every Discord token, including the desktop client's, and forces re-auth.
[ ] Change Steam password and deauthorize all other devices. Re-log in everywhere you actually use Steam.
[ ] Audit Cloudflare API tokens, registrar API tokens, and hosting provider API tokens for unfamiliar entries.
[ ] Audit DNS records for every domain you own — the attacker may have added subdomains pointed at their infrastructure.
[ ] Delete the Windows user account and recreate. Persistence in HKCU Run keys, user-scope scheduled tasks, Startup folder, and AppData is harder to enumerate exhaustively than to nuke. Recreating the user is the safe move.
[ ] Re-install Windows if you have any doubt about the user separation (e.g., FXServer ran as a user that has ever been added to the Administrators group, even temporarily).
```

---

## Windows host (FXServer.exe running directly) — Administrator

**Stop. The OS is compromised. The remediation is "reinstall Windows from clean media."**

There is no in-place clean for an admin-level Windows compromise. The reasons:

- An admin-level attacker can run `procdump.exe -ma lsass.exe` (or equivalent) and walk away with NTLM hashes for every user logged in since boot, plus Kerberos TGTs, plus cached domain creds if the box is domain-joined.
- An admin can install kernel-mode drivers (signed-driver bypass via [BYOVD](https://en.wikipedia.org/wiki/Bring_Your_Own_Vulnerable_Driver)), which run below every defensive tool.
- An admin can disable, modify, or selectively blind Windows Defender, EDR agents, antivirus, and event logging. Anything those tools report after compromise is untrustworthy.
- An admin can write to `\\?\GLOBALROOT\Device\HarddiskVolume*\Windows\System32\` directly, bypassing Windows File Protection.
- An admin can install WMI permanent event subscriptions that re-establish persistence on every boot.
- An admin can plant scheduled tasks in `Microsoft\Windows\` task folders that look exactly like Microsoft-shipped tasks.
- An admin can modify Image File Execution Options to attach a debugger ("debugger" is a euphemism for "any executable") to commonly-launched binaries.
- An admin can replace any service binary or DLL on disk.
- An admin can add their own root certificate to the Trusted Root Certification Authorities store, enabling silent MITM of HTTPS traffic.

There is no scan tool that exhaustively enumerates every persistence vector available to a Windows admin attacker. Even after running every commercial EDR, Sysinternals Autoruns, Process Hacker, KAPE, and PowerShell-based detection toolkit ever written, you have no guarantee. The only defensible response is to assume nothing on the disk is trustworthy.

### Action checklist

```
[ ] Disconnect the host from every network it is on (yank the cable; pull the NIC).
[ ] Decide whether you want forensics. If yes, image the drive (FTK Imager, dd, or your hosting provider's snapshot tool) and keep the image cold.
[ ] Treat every credential ever entered on this machine as exfiltrated (see the rotation reference card below).
[ ] Treat every device this machine ever RDP'd or SSH'd OUT to as also potentially compromised — identify which and rotate creds for those.
[ ] If the box was domain-joined: this is a domain incident. Stop and call your domain admin. Domain Admin or Account Operators credentials cached on this box may have been dumped.
[ ] Reinstall Windows from clean ISO media. Do not "reset" via the in-place repair option. Do not restore from a system image taken after the infection.
[ ] After reinstall, restore data only from backups pre-dating the infection, OR by hand-vetting individual files (no executables, no scripts, no Office docs with macros).
[ ] Reinstall FiveM and txAdmin from official sources, with rotated keys.
[ ] If the machine has an unusually capable adversary in scope, also consider firmware reflash. For a panel-class adversary like Blum this is overkill, but it is the upper bound of what a Windows admin compromise enables.
```

---

## Windows host that you also use as a workstation

This is the worst case and depressingly common: a single Windows VPS or dedicated server runs FXServer **and** you RDP to it, browse with Chrome/Edge from the same RDP session, run Discord, manage your Cloudflare/registrar/hosting/GitHub through that browser, sign in to your bank to pay for the box, and use Steam to play between scripting sessions.

If FXServer was infected on a machine like this, **every credential you have ever entered on it is potentially in the attacker's hands.** Not just FiveM-related accounts. Everything.

The action list is the Windows admin reinstall above, plus the Windows non-admin force-logout-everywhere globally — applied to every account, not just FiveM-related ones. Plus the rotation reference card below applied at maximum scope.

If you only do one thing, force-logout-everywhere on every service in the rotation card before doing anything else. That cuts the attacker's session-cookie access immediately. Password rotation can follow.

---

## Rotation reference card

A flat checklist of credential types that are commonly relevant. Use it as a tick-list during recovery.

### FiveM-specific

```
[ ] txAdmin master password
[ ] txAdmin admin accounts (delete unknown ones; JohnsUrUncle is the known backdoor name; assume there may be others)
[ ] rcon_password (server.cfg)
[ ] sv_licenseKey (revoke and regenerate via keymaster.fivem.net)
[ ] Cfx.re forum account password (txAdmin uses this for some flows)
[ ] Database user password used by FiveM (MySQL/MariaDB)
[ ] Framework admin password (ESX/QBCore/vRP/vMenu/etc.)
[ ] Every Discord webhook URL referenced in any resource
[ ] Every Discord bot token referenced in any resource
[ ] Patreon-linked Cfx.re benefits (recheck account email + 2FA)
```

### Server infrastructure

```
[ ] Pterodactyl panel admin password (and every user password on the panel)
[ ] Hosting provider account (Vultr, OVH, Hetzner, AWS, GCP, Azure, Digital Ocean, Linode)
[ ] Hosting provider API tokens / service-account keys
[ ] Domain registrar (and registrar API tokens)
[ ] Cloudflare account password and API tokens
[ ] Cloudflare DNS records for every domain (audit for unauthorized changes; especially new subdomains, MX changes, NS changes, TXT records)
[ ] SSH keys (regenerate, replace authorized_keys on every box)
[ ] RDP user passwords on every Windows host
[ ] VPN configs and any embedded credentials
[ ] Any monitoring service API tokens (Grafana, Datadog, New Relic, Sentry)
```

### Personal accounts (only relevant if FXServer ran on a Windows workstation you also use)

```
[ ] Discord (account password — invalidates client tokens)
[ ] Steam (password + deauthorize all devices via Steam Guard)
[ ] Every game launcher (Epic, Riot, Battle.net, EA, Ubisoft, GOG)
[ ] Every email provider account password and re-enrol MFA
[ ] Every social media account
[ ] Every password manager — rotate the master password and force-logout-all-devices
[ ] Every browser-saved password (treat all of them as known)
[ ] Every banking and crypto exchange account
[ ] Every subscription service that retains payment info
[ ] Every dev tool with cached creds (GitHub, GitLab, AWS CLI, gcloud, Azure CLI, kubectl, Docker Hub, npm, PyPI, etc.)
[ ] OAuth grants — review and revoke unknown ones for each major identity provider (Google, Microsoft, GitHub, Discord)
[ ] Every TOTP secret stored in a browser-extension or desktop authenticator (re-enrol)
[ ] Every API key for every SaaS that issues them
```

---

## Specific credential types worth understanding

Operators sometimes try to "just change the password" and assume it's done. Some credentials don't work that way.

- **Discord client token** — exists as a long-lived value in the desktop client's leveldb. Changing your Discord password invalidates all tokens. Just deleting the leveldb without rotating the password leaves the attacker's exfiltrated copy still valid.
- **Steam ssfn files** — session keepers in the Steam install directory. Anyone with these files can sign in to your Steam account without triggering the Steam Guard email confirmation. Rotation: change Steam password and choose "Deauthorize all other computers" in Steam Guard. Re-log in everywhere you actually use Steam.
- **Browser session cookies** — credential-equivalent for any site that doesn't require step-up auth. Changing the password does NOT necessarily invalidate active sessions. Use each provider's "log me out of all sessions" feature in addition to changing the password.
- **OAuth refresh tokens** — embedded in many desktop apps and CLIs. Changing the upstream password may or may not revoke them depending on the provider. Manually revoke via "connected apps" / "third-party access" pages in each major identity provider.
- **TOTP / authenticator app secrets** — the secret seed is what generates codes. If a browser-resident authenticator is compromised, the attacker can generate codes too. Rotation: re-enrol the factor with a new secret (the QR code / secret string). Hardware keys (YubiKey, Titan, etc.) are not affected.
- **API tokens** — long-lived, often without expiry. Rotate every one for every service you've used; an attacker with the API token can do whatever the token's scope allows even after the owner's password rotation.
- **SSH agent forwarding** — if you SSH'd into the FXServer host with `-A`, your local SSH agent's keys were available to processes on that host. The keys themselves were not exfiltrated, but the attacker could have used them through the agent socket while you were connected. Rotate the keys.
- **Domain DNS** — easy for the attacker to add their own records (a CAA record allowing their CA, a TXT record for a forged ACME challenge, an MX record to intercept email-based password resets). Audit DNS for every domain whose registrar/CDN account was reachable from the compromised machine.

---

## Keep the evidence

Before you wipe, snapshot. Even if you don't intend to chase the attacker, an image is cheap insurance:

- Cloud VPS: most providers offer instant snapshots; take one and label it "compromised — keep cold."
- Bare-metal: image with FTK Imager, `dd`, or `ddrescue` to external storage that you then disconnect.
- For Windows specifically, run `detection/blum_windows.ps1 -Action Forensics -Path C:\FXServer\server-data -OutputDir .\evidence -IncludeHashes -IncludeForensicsZip` first. That gets you a portable triage bundle (process list, TCP connection list, hosts file copy, recent event log windows, SHA256 baseline of resources, txAdmin config copy) that you can preserve without keeping the whole drive.

Evidence enables three things later: confidently proving cleanliness on the rebuilt host (compare against the pre-rebuild hash baseline), responding to law enforcement or your hosting provider's abuse team, and contributing to the broader community's IOC database if you find new artefacts.

---

## After you finish

Once you've completed the appropriate checklist, run the scanner one more time on the rebuilt environment. A clean scan is necessary but not sufficient — it confirms the files are gone, not that the credentials, sessions, or persistence are. Confidence comes from the credential rotation work, not from the scanner output.

Then deploy the runtime protection in `dropper_trap/` so that the next time someone tries to install a Blum-family resource, the dropper trips before it can phone home.

Stay paranoid. The whole reason this backdoor worked at scale is that operators trusted resources they didn't audit.

---

## See also

- [`docs/TXADMIN_TAMPERING.md`](TXADMIN_TAMPERING.md) — five txAdmin tampering points walkthrough with code snippets and the recommended reinstall procedure
- [`docs/HARDENING.md`](HARDENING.md) — defense-in-depth playbook for hardening your server *before* the next infection, so the blast radius is bounded by design rather than mitigated by recovery
- [`detection/blum_windows.ps1`](../detection/blum_windows.ps1) — Windows tooling (Scan / Audit / Forensics / Block / Remediate / Baseline / Compare)
- [`dropper_trap/`](../dropper_trap) — FiveM-side runtime trap (deploy as the first `ensure` in `resources.cfg`)
- [`iocs/blum_iocs.json`](../iocs/blum_iocs.json) — canonical IOC inventory consumed by every scanner and runtime trap in this repo
