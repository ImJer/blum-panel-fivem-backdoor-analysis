# Blum Panel — Attacker Identity & Financial Intelligence

## Operator Identity

### Discord Admin Accounts (hardcoded in panel frontend `Hf` array)
| Discord ID | Created (approx) | Role |
|------------|-------------------|------|
| `393666265253937152` | ~Late 2018 | Primary operator / owner |
| `1368690772123062292` | ~May 2025 | Secondary admin |

### Discord OAuth Application
- **Client ID:** `1444110004402655403`
- **Redirect:** `https://blum-panel.me` and `https://warden-panel.me`
- **Scope:** `identify` (reads Discord user info)

### Known Handles
- bertjj, bertjjgg, bertjjcfxre, miausas, miauss
- Discord server: discord.com/invite/VB8mdVjrzd
- Also linked: discord.gg/ciphercorp (Cipher Panel Discord)

---

## Brand History (same operation, rebranded)

| Period | Brand | Domain | Evidence |
|--------|-------|--------|----------|
| 2021–2025 | **Cipher Panel** | cipher-panel.me | Cfx.re forum reports, Discord invite in code, URLs in panel JS bundle |
| 2025–2026 | **Blum Panel** | blum-panel.me | Primary brand, SEO-optimized landing page |
| 2026+ | **Warden Panel** | warden-panel.me | Rebrand/alias, same Express backend, same Socket.IO |

Evidence of connection: Panel JS bundle (`index-BmknYBUo.js`) contains hardcoded URLs to `cipher-panel.me/secure_area/fivem/sv/typer/` and references to `discord.gg/ciphercorp`.

---

## Cryptocurrency Wallets

### Bitcoin (BTC)
- **Address:** `bc1q2wd7y6cp5dukcj3krs8rgpysa9ere0rdre7hhj`
- **Total received:** 0.02353255 BTC (~$2,000-$2,100)
- **Current balance:** 0.02078484 BTC (~$1,800)
- **Transactions:** 9
- **Active period:** November 28, 2025 — February 28, 2026

Transaction history:
```
2025-11-28  RECEIVED  0.00119000 BTC  (first payment)
2025-12-31  RECEIVED  0.00160900 BTC
2026-01-02  RECEIVED  0.01331293 BTC  (largest — likely lifetime plan)
2026-01-04  RECEIVED  0.00064200 BTC
2026-01-15  RECEIVED  0.00170494 BTC
2026-01-25  RECEIVED  0.00091571 BTC + WITHDRAWAL
2026-02-01  RECEIVED  0.00052909 BTC + WITHDRAWAL
2026-02-25  RECEIVED  0.00102200 BTC
2026-02-28  RECEIVED  0.00260688 BTC  (most recent)
```

### Litecoin (LTC) — PRIMARY PAYMENT CHANNEL
- **Address:** `LSxKJm6SpdExCACUcFTUADcvZgea65AaWo`
- **Total received:** 76.53 LTC (~$7,600-$9,900)
- **Total withdrawn:** 44.97 LTC
- **Current balance:** 31.56 LTC
- **Transactions:** 89 (88 incoming)
- Estimated **60-90 unique customers** based on transaction count and pricing

### Solana (SOL)
- **Address:** `vDWomGGtBctKqtTkRm6maXc7KJrvtmc2x8WXEzbuzkz`
- No transaction data retrieved (may be inactive or invalid address)

### Alternative Payment Methods
- **Amazon Gift Cards (GBP):** £50 and £120 denominations
  - Purchase links to eneba.com and g2a.com in panel
  - GBP denomination suggests **UK-based customer base**
- **MoonPay:** Fiat-to-crypto integration (moonpay.com/en-gb — also UK)
- **CoinGecko:** Price checking in **EUR** (seller prices in Euros)

### Combined Revenue Estimate
- BTC: ~$2,000
- LTC: ~$8,000-$10,000
- Gift cards: unknown (untraceable)
- **Minimum total: ~$10,000-$12,000** from crypto alone
- Operation active since 2021 under Cipher brand — total lifetime revenue likely significantly higher

---

## Pricing

| Plan | Price | Duration |
|------|-------|----------|
| Basic | €59.99 | Monthly |
| Ultima | €139.99 | Lifetime |

Payment webhook security code: `1221885230680375427`
Payment webhook endpoint: `<backend>/api/payment-webhook`

---

## Infrastructure

### Origin C2 Backend Server
- **IP:** 185.87.23.198
- **Hosting:** active 1 GmbH (active-servers.com)
- **Location:** Hamburg, Germany
- **ASN:** AS197071
- **Port:** 5000 (Express.js/Node.js)
- **Purpose:** Panel backend — the real server behind all Cloudflare domains
- **Note:** All panel domains (blum-panel.me, warden-panel.me, 9ns1.com, fivems.lt) proxy to this IP

### C2 Domains (behind Cloudflare)
- **Primary active:** 9ns1.com (fivems.lt is dying — returns 12 bytes on some endpoints)
- **IPs:** Cloudflare proxy (172.67.x.x, 104.21.x.x)
- **SSL issuer:** Google Trust Services (WE1)
- **SSL cert renewed:** March 12, 2026 (actively maintained)
- **Backend:** Express.js (x-powered-by: Express)
- **Note:** API keys are generated dynamically — ANY key works, not access-controlled

### File Hosting Server
- **IP:** 185.80.128.35
- **Hosting:** UAB "Esnet" (VPSNET-COM)
- **Address:** Zuvedru g. 36, Vilnius, Lithuania LT-10103
- **Abuse contact:** abuse@vpsnet.lt
- **Server:** Apache/2.4.29 (Ubuntu 18.04)
- **Open ports:** 22 (SSH), 80 (HTTP)
- **Purpose:** Stolen resource ZIP hosting at /download-resource/<filename>

### Panel Domains (all behind Cloudflare)
| Domain | Backend | SSL Issuer | Status |
|--------|---------|------------|--------|
| 9ns1.com | Express.js | Google Trust Services | **Active primary** |
| fivems.lt | Express.js | Google Trust Services | **Dying** (some endpoints dead) |
| blum-panel.me | Express.js | Google Trust Services | Active |
| blum-panel.com | Express.js | Google Trust Services | Active |
| warden-panel.me | Express.js | Google Trust Services | Active |
| cipher-panel.me | nginx/1.18.0 | Google Trust Services | Separate (original) |

### Additional IOCs
| Asset | Value |
|-------|-------|
| Google Analytics | G-NVDGG6CWYJ |
| Vimeo channel | vimeo.com/channels/1864287 |
| Discord Guild ID | 1306715469776158771 |
| Webhook Channel ID | 1390045431446372372 |
| Webhook Name | "Captain Hook" |
| Webhook Status | DELETED by JGN (HTTP 204 confirmed, now 404) |

### Cipher Panel Additional Domains
| Domain | Purpose |
|--------|---------|
| cipher-panel.me | Original panel |
| ciphercheats.com | Cipher brand |
| keyx.club | Cipher brand |
| dark-utilities.xyz | Cipher brand |

### Obfuscation
- **Tool:** JScrambler (commercial JavaScript obfuscator)
- **Bloat ratio:** ~200:1 (425KB for 50 lines of dropper code)
- **Cost:** JScrambler pricing starts at ~$100/month

---

## Geographic Indicators

| Indicator | Points to |
|-----------|-----------|
| Origin server 185.87.23.198 (active 1 GmbH) | **Hamburg, Germany** |
| .lt domain TLD | Lithuania |
| File server hosting (UAB Esnet, Vilnius) | Lithuania |
| GFX Panel hosting (UAB Esnet, Vilnius) | Lithuania |
| jking.lt in C2 domain list | Lithuania |
| EUR pricing | European Union |
| GBP gift cards | UK customer base |
| moonpay.com/en-gb | UK customers |
| cipher-panel.me nginx server | Separate infrastructure |

---

## Admin API Routes (server-side auth validated)

```
GET  /admin/stats                    — Panel statistics
GET  /admin/users                    — All customers
GET  /admin/servers?page=N&limit=N   — Infected server list (paginated)
GET  /admin/payloads                 — All payloads
GET  /admin/activity                 — Activity log
POST /admin/users                    — Create customer
PUT  /admin/users/{api}              — Update customer
DELETE /admin/users/{api}            — Delete customer
DELETE /admin/servers/{id}           — Delete server
```

Auth header: `x-discord-id: <discord_user_id>`
Note: Server-side validates Discord ID against database, not just the frontend `Hf` array. Cannot be bypassed with spoofed headers alone.

---

## Abuse Report Contacts

| Service | Contact | Report For |
|---------|---------|------------|
| Cloudflare | abuse@cloudflare.com | fivems.lt, blum-panel.me, warden-panel.me — malware C2 |
| UAB Esnet | abuse@vpsnet.lt | 185.80.128.35 — stolen file hosting |
| Discord | Trust & Safety | discord.com/invite/VB8mdVjrzd, App ID 1444110004402655403, User IDs 393666265253937152 & 1368690772123062292 |
| Cfx.re | FiveM Team | Full analysis package |
| .lt registrar | DOMREG.lt | fivems.lt, jking.lt — malware distribution |
| JScrambler | Notify of misuse | Commercial obfuscator used for malware |

---

## Luraph Lua Payloads (Discovered March 14, 2026)

### Overview
Three Lua-based initial infection payloads served from fivems.lt, obfuscated with Luraph v14.6.
These are the FIRST STAGE — they drop XOR-encrypted JS files that fetch the full 1.6MB replicator.

### Payload Variants

| Endpoint | Size | MD5 | API Key | C2 Target |
|----------|------|-----|---------|-----------|
| `/test` | 65,564 bytes | 97a72874d068f103e75306a314839f1f | zXeAH | 9ns1.com/zXeAHJJ |
| `/dev` | 64,115 bytes | a6fa269b841893eeb39b900fdd29e66a | dev | fivems.lt/devJJ |
| `/null` | 64,289 bytes | 01df43eefebdc1f134a4872a6e78a24a | null | fivems.lt/nullJJ |

### Second C2 Domain: 9ns1.com
The `test` payload (API key "zXeAH") connects to `https://9ns1.com/zXeAHJJ` instead of fivems.lt.
This is a previously unknown C2 domain. The attacker is distributing infrastructure across domains.

### Discord Webhook (Phone-Home)
All three payloads share the same Discord webhook for infection notifications:
- **Webhook ID:** 1470175544682217685
- **URL:** `https://discord.com/api/webhooks/1470175544682217685/pe8DNcnZCjKPlKF24tk72Riv6bfQcFM6rmMvrwx_YeGm0P1oVtDHxp4_HbKCHvRiPBJP`
- **Purpose:** Sends embed with resource name, server hostname, and player count on each new infection
- **Embed title:** Set to the API key (dev/null/zXeAH) so attacker knows which variant infected

### Dual Obfuscator Setup
| Layer | Obfuscator | Language | Cost |
|-------|------------|----------|------|
| Initial infection | Luraph v14.6 | Lua | ~$20/month |
| JS dropper + replicator | JScrambler | JavaScript | ~$100/month |

### API Key Pattern
All C2 endpoints follow the pattern: `/<key>JJ`
- bertJJ (original), bertJJgg (fallback), bertJJcfxre (fallback)
- devJJ
- nullJJ
- zXeAHJJ (on different domain)

### JS Dropper Characteristics (polymorphic)
- Filename randomly chosen: entry.js, init.js, stack.js, runtime.js, interface.js, bridge.js
- XOR key format: "r" + 4 random digits (e.g., r2464, r5246)
- Payload wrapped in 700+ byte space comment block
- Decryption via `require('vm').runInThisContext(decoded)`
- Persistence via KVP key "installed_notices"

### Self-Reported Version: v4.5
The webhook embed footer contains "v4.5", indicating the attacker tracks versions.
