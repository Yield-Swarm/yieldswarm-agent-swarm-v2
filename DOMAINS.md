# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production wiring for YieldSwarm + Kairo: Vercel/Netlify frontends, Akash API
endpoints, treasury crypto records, and subdomain layout.

> This is a runbook. Apply records in the Unstoppable Domains dashboard and/or
> Cloudflare. Secrets (`UD_API_KEY`, treasury keys) live in HashiCorp Vault only.

---

## 1. Domain inventory

| Domain | Purpose | Primary host |
|--------|---------|--------------|
| `yieldswarm.crypto` (or your UD name) | Main YieldSwarm site | Vercel `v2-0-bay.vercel.app` |
| `yieldswarm.blockchain` | IPFS decentralized site | CID `QmQUS42xN6Ej21baZZCMmxnirwzy9XFRPruqUYTof4vwTz` — see `docs/IPFS_YIELDSWARM_BLOCKCHAIN.md` |
| `kairo.x` (or subdomain) | Kairo driver/customer app | Netlify/Vercel Kairo deploy |
| `app.<domain>` | Application frontend | Vercel |
| `api.<domain>` | Backend + Arena telemetry API | Akash worker / Cloudflare proxy |
| `dashboard.<domain>` | $5M vault + OpenClaw admin | Static `dashboard/sovereign-dashboard.html` |
| `kairo-api.<domain>` | Kairo driver identity API | Akash or `kairo/backend` on port 8100 |

Current Vercel project: https://v2-0-bay.vercel.app/ (see `README.md`).

---

## 2. DNS records (Path A — traditional, recommended)

Set these in **Unstoppable Domains → Manage → DNS** or delegate to **Cloudflare**.

### Website / frontend

| Host | Type | Value | Notes |
|------|------|-------|-------|
| `@` | Website URL | `https://v2-0-bay.vercel.app` | Apex redirect |
| `app` | CNAME | `cname.vercel-dns.com` | Vercel shows exact target per project |
| `kairo` | CNAME | Netlify/Vercel deploy hostname | Kairo frontend (`kairo/frontend`) |
| `dashboard` | CNAME | Same as `app` or static bucket | Serves sovereign dashboard |

### API / backend

| Host | Type | Value | Notes |
|------|------|-------|-------|
| `api` | CNAME | Akash worker hostname | From `.run/akash-lease.env` after deploy |
| `kairo-api` | CNAME | Akash Kairo service URI | Port 8100 exposed in SDL |

### Cloudflare (if used as resolver)

1. UD dashboard → set custom nameservers to Cloudflare NS pair.
2. Cloudflare zone → add records above; enable **Proxied** + **Full (strict)** TLS.
3. Page Rules: `api.*` → disable cache; `app.*` → cache static assets.

---

## 3. Crypto treasury records

Set in UD dashboard → domain → **Crypto / Addresses**:

| Record | Example placeholder | Purpose |
|--------|---------------------|---------|
| `crypto.ETH.address` | `0x9505578Bd5b32468E3cEa632664F7b8d2e46128c` | EVM treasury (from architecture docs) |
| `crypto.SOL.address` | Your Squads/multisig SOL address | Solana treasury |
| `crypto.TON.address` | Your TON treasury wallet | TON Connect deposits |

**Do not** put the `$APN` mint address (`8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump`) in
`crypto.SOL.address` — that is a token mint, not a wallet.

Verify every address character-by-character before signing the on-chain UD transaction.

---

## 4. Subdomain → service map

```
yieldswarm.crypto          → Vercel (main YieldSwarm)
app.yieldswarm.crypto      → Vercel (payments + wallet)
api.yieldswarm.crypto      → Akash worker (Arena telemetry, Odysseus proxy)
dashboard.yieldswarm.crypto → Sovereign $5M dashboard
kairo.yieldswarm.crypto    → Kairo ride/delivery app
kairo-api.yieldswarm.crypto → Kairo driver identity + telemetry API
```

Backend routes (after deploy):

- `GET /api/health` — integration backend health
- `GET /api/telemetry/akash` — Akash worker telemetry (Arena)
- `GET /api/telemetry/odysseus` — Odysseus agent telemetry
- `GET /api/arena/overview` — aggregated Arena dashboard
- `POST /api/v1/drivers/identity` — Kairo driver registration (Kairo API)

---

## 5. Akash wiring (post-deploy)

After `make akash-lease`:

```bash
source .run/akash-lease.env
echo "$AKASH_WORKER_URLS"
```

1. Put Cloudflare (or nginx) in front of the Akash hostname for stable `api.*`.
2. Update UD `api` CNAME to the stable proxy hostname.
3. Re-run `make frontend` to inject worker URLs into `dashboard/config.js`.

SDL files: `deploy/deploy-swarm-monolith.yaml`, `deploy/akash/deploy.sdl.yaml`.

---

## 6. Vault-injected secrets for domains

Store in Vault path `kv/yieldswarm/domains/runtime`:

| Key | Used by |
|-----|---------|
| `UD_API_KEY` | Programmatic UD record updates |
| `VERCEL_TOKEN` | Domain attach + redeploy |
| `NETLIFY_AUTH_TOKEN` | Kairo frontend deploy |
| `MAPBOX_ACCESS_TOKEN` | Kairo map tracking |

Load at deploy time:

```bash
source scripts/lib/vault-env.sh
vault_export_env kv/data/yieldswarm/domains/runtime
```

---

## 7. Verification checklist

- [ ] `@` Website record resolves to Vercel
- [ ] `app.`, `api.`, `kairo.`, `dashboard.` resolve (browser + `dig`)
- [ ] `crypto.ETH`, `crypto.SOL`, `crypto.TON` verified on-chain
- [ ] HTTPS valid, no mixed content
- [ ] `UD_API_KEY` rotated if previously exposed; new key in Vault only
- [ ] Akash worker `/healthz` reachable via `api.*` proxy

---

## 8. Programmatic UD updates (optional)

```bash
source scripts/lib/vault-env.sh
vault_export_env kv/data/yieldswarm/domains/runtime

curl -s "https://api.unstoppabledomains.com/resolve/domains/yieldswarm.crypto" \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

Reference: https://docs.unstoppabledomains.com/
