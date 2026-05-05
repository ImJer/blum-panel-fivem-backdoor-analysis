# IOC inventory

This directory holds the indicators of compromise for the Blum / Warden / Cipher / GFX Panel FiveM backdoor family.

## Canonical source

[`blum_iocs.json`](blum_iocs.json) is the canonical IOC inventory. It's structured by category (C2 domains, direct IPs, attacker handles, txAdmin tampering markers with per-file mapping, dropper filenames, obfuscation residue, JJ-suffix operator API keys, Discord webhook IDs, GlobalState mutexes, payload size ranges) so tools and humans can consume the same data.

## Tools that consume this data

The IOC lists are inlined into each tool for portability (so a single download of `blum_windows.ps1` or `dropper_trap/` works without bundling extra files). When you edit `blum_iocs.json`, mirror the change into the tools that ship those IOCs:

| Tool | File | Purpose |
|------|------|---------|
| Linux scanner | [`../detection/scan.sh`](../detection/scan.sh) | 13-check static scanner |
| Linux blocker | [`../detection/block_c2.sh`](../detection/block_c2.sh) | iptables + hosts file C2 block |
| Windows tooling | [`../detection/blum_windows.ps1`](../detection/blum_windows.ps1) | Scan / Audit / Forensics / Block / Remediate / Baseline / Compare |
| Runtime trap (Lua) | [`../dropper_trap/trap.lua`](../dropper_trap/trap.lua) | FiveM-side runtime hooks |
| Runtime trap (JS) | [`../dropper_trap/trap.js`](../dropper_trap/trap.js) | FiveM-side runtime hooks (JS context) |

## Other files in this directory

- `domains.txt` — flat list of C2 domains (handy for piping into other tools)
- `hosts_block.txt` — `0.0.0.0`-prefixed `hosts`-file blocklist
- `pihole_block.txt` — Pi-hole-formatted blocklist
- `pastebin_urls.txt` — fallback URLs observed in the C2 protocol
- `strings.txt` — flat string IOCs
- `hashes.txt` — SHA256/MD5 hashes of observed payloads
- `socket_io_protocol.md` / `socket_io_protocol_full.js` — captured Socket.IO C2 protocol
- `attacker_intel.md` — attacker identity, wallets, origin IP analysis

## Reporting new IOCs

If you've found a new marker, dropper filename, C2 domain, or behaviour that this inventory doesn't already cover, please open an issue using the [**New IOC Report** template](../../issues/new?template=new-ioc.md) — it walks you through the fields needed to add an entry to `blum_iocs.json`.

## Maintenance

The Blum family has rotated minor markers in the past. If `blum_iocs.json` hasn't been updated in 90 days, that's a signal to do a refresh sweep — not necessarily because new IOCs exist, but because the lack of community signal usually means the threat hasn't gone away.
