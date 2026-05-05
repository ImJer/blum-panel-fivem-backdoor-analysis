---
name: Scanner Findings — "Can someone take a look?"
about: You ran scan.sh / blum_windows.ps1 / dropper_trap, got hits or unfamiliar output, and want help interpreting it
title: "[Scanner] "
labels: ["scanner-findings", "needs-triage"]
---

<!--
This template is for sharing scanner output when something fired that you
weren't expecting and you'd like a second pair of eyes. Sharing is entirely
optional and the repo never auto-reports anything — copy whatever you're
comfortable with into the sections below and submit when ready. Skip any
section that doesn't apply.

If your scanner output prints a "BEGIN COPY-PASTE TEMPLATE" / "END COPY-PASTE
TEMPLATE" block, you can paste that whole block below and replace this
template — it's already pre-filled with the relevant fields.
-->

## Which tool surfaced the findings?

- [ ] `detection/scan.sh` (Linux)
- [ ] `detection/blum_windows.ps1` (Windows) — action: <!-- Scan / Audit / Forensics / Block / Remediate / Compare -->
- [ ] `dropper_trap/` (FiveM runtime trap)
- [ ] `detection/baseline.sh` + `compare.sh` drift detection
- [ ] Other:

## Scanner output

<!-- Paste the relevant output. Trim absolute paths if you want to redact your install location. -->

```
PASTE OUTPUT HERE
```

## Environment

- Where is FXServer running? (Pterodactyl/Docker, Linux host, Windows host non-admin, Windows host admin, Windows-also-workstation):
- OS:
- FXServer build (if known):
- txAdmin version (if applicable):
- Scanner version (commit SHA from this repo, if known):

## What did you do before this fired?

<!-- e.g. "installed a new resource", "first run after upgrading FXServer", "routine weekly scan", "after seeing weird player behaviour" -->

## What's your read on it?

<!-- 
Even if you're guessing, your context helps us triage. Examples:
- "I think it's a false positive because resource X always uses load() for legitimate reasons"
- "I saw a new admin in txAdmin I don't recognise, scanned and got these hits"
- "Drift comparison says sv_resources.lua changed but I haven't updated txAdmin"
-->

## What have you already done?

- [ ] Read [`docs/BLAST_RADIUS.md`](https://github.com/ImJer/blum-panel-fivem-backdoor-analysis/blob/main/docs/BLAST_RADIUS.md)
- [ ] Read [`docs/TXADMIN_TAMPERING.md`](https://github.com/ImJer/blum-panel-fivem-backdoor-analysis/blob/main/docs/TXADMIN_TAMPERING.md)
- [ ] Stopped the FiveM server
- [ ] Imaged / snapshotted the host for evidence
- [ ] Started rotating credentials
- [ ] Other (describe):

## Anything else worth knowing?

<!-- Anti-analysis behaviour, novel output, anything that looks new -->

---

*Sharing is optional. Privacy-friendly: this repo never auto-reports anything from your server. We'll respond as soon as someone has time to triage. If your situation is urgent and you're actively under attack, see the **Reporting Contacts** section in the README for direct routes (Cfx.re, Cloudflare abuse, hosting provider abuse).*
