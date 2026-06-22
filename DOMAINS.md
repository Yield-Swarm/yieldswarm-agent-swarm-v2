# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

**Canonical SSOT** for YieldSwarm + Kairo domain track: Vercel frontends, Akash API,
treasury crypto records, Phase 1 / Phase 2 routing, and `yieldswarm.blockchain` IPFS.

> Apply records in the [Unstoppable Domains](https://unstoppabledomains.com) dashboard.
> Secrets (`UD_API_KEY`, treasury keys) live in **HashiCorp Vault only** — never git.

Machine-readable registry: `config/domains/registry.json`

---

## Phase overview

| Phase | When | Frontend | API / workers |
|-------|------|----------|---------------|
| **Phase 1** | Tonight | Vercel `v2-0-bay.vercel.app` | `api.*` → `gateway.yieldswarm.crypto` placeholder OR Vercel `/api` |
| **Phase 2** | After first Akash deploy | Same Vercel | `api.*`, `worker.*`, `arena.*` → Cloudflare Worker → Akash lease |

---

## Pre-flight (do before any UD records)

1. **Rotate `UD_API_KEY`** if it appeared in chat, tickets, or logs. Delete legacy keys (`Mcpyieldswarmprod`, `Yieldswarmprod`, `YSMASTERUNSTPDOM`, etc.).
2. **Seed Vault only:**
   ```bash
   export VAULT_ADDR=https://vault.yieldswarm.io:8200
   export VAULT_TOKEN=...          # admin — one-time
   export UD_API_KEY=...           # new key from UD portal — shell only
   ./vault/scripts/seed-secrets.sh
   unset UD_API_KEY
   ```
   Paths: `yieldswarm/integrations/unstoppable` → `api_key`; optional `yieldswarm/domains/runtime`.
3. **Vercel first** — Project Settings → Domains → add apex + subdomains **before** UD CNAMEs:
   - `yieldswarm.crypto`, `www.yieldswarm.crypto`, `app.yieldswarm.crypto`
   - `dashboard.yieldswarm.crypto`, `status.yieldswarm.crypto`
   - `kairo.x`, `app.kairo.x`
   - Copy the exact `cname.vercel-dns.com` target Vercel shows per domain.

---

## 1. `yieldswarm.crypto` — Phase 1 records (copy-paste)

Set in UD → **My Domains** → `yieldswarm.crypto` → **Manage**.

| Record type | Name / subdomain | Value | Purpose |
|-------------|------------------|-------|---------|
| **Website** | `@` | `https://v2-0-bay.vercel.app` | Main site + hero metrics |
| **CNAME** | `www` | `cname.vercel-dns.com` | Use exact value from Vercel |
| **CNAME** | `app` | `cname.vercel-dns.com` | App / Kairo flows |
| **CNAME** | `dashboard` | `cname.vercel-dns.com` | $5M vault + Arena telemetry |
| **CNAME** | `status` | `cname.vercel-dns.com` | Council / governance |
| **CNAME** | `api` | `gateway.yieldswarm.crypto` | Phase 2 stable proxy (placeholder OK tonight) |
| **crypto.ETH.address** | `@` | Your Gnosis Safe / EVM treasury multisig | Treasury |
| **crypto.BTC.address** | `@` | Your BTC treasury multisig | Treasury |
| **crypto.SOL.address** | `@` | Your Squads multisig (**not** the $APN mint) | Treasury |

---

## 2. `kairo.x` — Phase 1 records

| Record type | Name / subdomain | Value | Purpose |
|-------------|------------------|-------|---------|
| **Website** | `@` | `https://v2-0-bay.vercel.app/kairo` | Kairo ride/delivery + Mapbox |
| **CNAME** | `app` | `cname.vercel-dns.com` | Sub-app entry |
| **crypto.ETH.address** | `@` | Same EVM treasury as `yieldswarm.crypto` | Shared treasury |
| **crypto.SOL.address** | `@` | Same SOL treasury as above | Shared treasury |

---

## 3. Additional apex domains (same pattern)

Apply the **Website `@`** + **CNAME subdomains** pattern. Change only the Website path:

| Domain | Website `@` target | Notes |
|--------|----------------------|-------|
| `depin.crypto` | `https://v2-0-bay.vercel.app/dashboard/depin-hq-sync.html` | DePIN HQ |
| `z15.crypto` | `https://v2-0-bay.vercel.app/marketplace` | Z15 / mining marketplace |
| `council.crypto` | `https://v2-0-bay.vercel.app/council` | Governance |
| `yieldswarm.blockchain` | IPFS: `QmQUS42xN6Ej21baZZCMmxnirwzy9XFRPruqUYTof4vwTz` | Gasless UD IPFS field — see `docs/IPFS_YIELDSWARM_BLOCKCHAIN.md` |

**17-zone layout** (on `yieldswarm.crypto`):

| Zone | Phase 1 | Phase 2 |
|------|---------|---------|
| `@`, `www`, `app`, `arena`, `portal`, `kairo`, `dashboard`, `council`, `staging`, `docs` | Vercel CNAME | Vercel CNAME |
| `api`, `kairo-api`, `helix`, `vault`, `odysseus`, `sovereign`, `cdn`, `monitor` | `gateway.*` placeholder | Cloudflare Worker → Akash |

Automated wiring (after Vault + Vercel token): `npm run domains:wire`

---

## 4. Phase 2 — `gateway.yieldswarm.crypto` (Akash proxy)

After `make akash-lease` or `./scripts/akash-mainnet-production.sh`:

1. Deploy Cloudflare Worker: `workers/gateway-yieldswarm-crypto.js`
2. Route `gateway.yieldswarm.crypto/*` to the Worker
3. Set Worker secret `AKASH_ORIGIN` from `.run/akash-lease.env`
4. Point `api.yieldswarm.crypto` CNAME → `gateway.yieldswarm.crypto`
5. Add `worker.`, `arena.`, `telemetry.`, `odysseus.`, `grafana.` → gateway or direct Akash host

```bash
source .run/akash-lease.env
# Cloudflare: wrangler deploy workers/gateway-yieldswarm-crypto.js
```

---

## 5. Subdomain → service map

```
yieldswarm.crypto           → Vercel (main YieldSwarm)
app.yieldswarm.crypto       → Vercel (payments + wallet)
api.yieldswarm.crypto       → gateway Worker → Akash (Phase 2)
dashboard.yieldswarm.crypto → Sovereign $5M dashboard
status.yieldswarm.crypto    → Council / Helix status
kairo.x                     → Kairo app (/kairo on Vercel)
yieldswarm.blockchain       → IPFS decentralized site
```

Backend routes (Akash / integration backend):

- `GET /healthz` — worker health
- `GET /api/health` — integration backend
- `GET /api/telemetry/akash` — Arena telemetry
- `GET /api/arena/overview` — aggregated dashboard

---

## 6. Vault secrets

| Vault path | Keys | Consumer |
|------------|------|----------|
| `yieldswarm/integrations/unstoppable` | `api_key` | UD API, verify script |
| `yieldswarm/domains/runtime` | `UD_API_KEY`, `VERCEL_TOKEN`, `CLOUDFLARE_*` | `wire-production-domains.sh` |

```bash
source scripts/lib/vault-env.sh
python3 scripts/vault-export-env.py multicloud  # or domains profile
```

Akash runtime **does not** receive `UD_API_KEY` (integrations allowed; cloud/providers denied).

---

## 7. Verification

```bash
# After DNS propagates (5–30 min)
npm run domains:verify-ud

# Manual
source scripts/lib/vault-env.sh
export UD_API_KEY="$(vault kv get -field=api_key yieldswarm/integrations/unstoppable)"
curl -s "https://api.unstoppabledomains.com/resolve/domains/yieldswarm.crypto" \
  -H "Authorization: Bearer ${UD_API_KEY}" | jq .
```

Checklist:

- [ ] `@` Website → Vercel URL visible in UD resolve
- [ ] `app.`, `dashboard.`, `status.` resolve (`dig` + browser)
- [ ] `crypto.ETH`, `crypto.SOL`, `crypto.BTC` match treasury multisigs
- [ ] `UD_API_KEY` rotated; only in Vault
- [ ] `yieldswarm.blockchain` IPFS CID set (gasless UD dashboard)
- [ ] Phase 2: `api.*` → gateway Worker → Akash `/healthz`

---

## 8. Repo commands

| Command | Purpose |
|---------|---------|
| `npm run domains:verify-ud` | UD API resolve check |
| `npm run domains:wire` | Wire 17 zones (Cloudflare + Vercel) |
| `./scripts/akash-mainnet-production.sh` | Akash deploy + Vault Agent |
| `docs/IPFS_YIELDSWARM_BLOCKCHAIN.md` | IPFS + UD on-chain record |

---

## Related

- [`docs/HELIX_SINGLE_PANE.md`](docs/HELIX_SINGLE_PANE.md) — 17-domain ingress diagram
- [`docs/VAULT_AKASH_RUNTIME.md`](docs/VAULT_AKASH_RUNTIME.md) — Akash + Vault Agent
- [`SECRETS.md`](SECRETS.md) — operator runbook
- [`scripts/wire-production-domains.sh`](scripts/wire-production-domains.sh)

Reference: https://docs.unstoppabledomains.com/
