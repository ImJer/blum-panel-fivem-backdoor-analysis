---
name: New IOC Report
about: Report a new Blum / Warden / Cipher / GFX Panel indicator (marker, filename, domain, IP, behaviour)
title: "[IOC] "
labels: ["ioc", "needs-triage"]
---

<!--
Thank you for taking the time to share this. Filling out as many sections as
you can helps us add the indicator to iocs/blum_iocs.json and update the
runtime trap and scanner tooling. Skip any section that doesn't apply.
-->

## What did you find?

<!-- e.g. "a new event name", "a new dropper filename", "a new C2 domain", "a new GlobalState mutex" -->

## The exact string / value

<!-- The full literal value as it appeared in your file. If it's a regex, label it as such. -->

```
PASTE HERE
```

## Where did it appear?

- File path (relative to FiveM server-data root):
- Resource name (if applicable):
- Surrounding lines (5–10 lines of context):

```
PASTE CONTEXT HERE
```

## How was it detected?

- [ ] `detection/scan.sh` flagged it
- [ ] `detection/blum_windows.ps1` flagged it
- [ ] `dropper_trap/` blocked / logged it at runtime
- [ ] Manual review
- [ ] Network capture / DNS log
- [ ] Other (describe):

## When did you first see it?

<!-- ISO date if you have it; "this week" / "after the May rotation" is fine -->

## Environment

- OS: <!-- Windows Server 2019 / Windows 11 / Ubuntu 22.04 / Pterodactyl Docker / etc. -->
- FXServer build: <!-- artifact number if known -->
- txAdmin version (if applicable):
- Scanner version (commit SHA from this repo, if known):

## Is this an active infection or a leftover artifact?

- [ ] Live / observed traffic in the last 7 days
- [ ] Found on disk during cleanup, source of infection unknown
- [ ] Theoretical / surfaced during code review of an unrelated resource
- [ ] Unsure

## Could you share an unredacted sample?

<!-- 
If yes, please don't paste it inline — it may be malicious. Reach out via the
contact in README "Reporting Contacts" and we'll arrange a private channel.
-->

- [ ] Yes, willing to share via private channel
- [ ] No, cannot share
- [ ] Already public (paste link if so)

## Anything else worth knowing?

<!-- Anti-analysis behaviour, novel persistence vector, evasion you noticed, etc. -->
