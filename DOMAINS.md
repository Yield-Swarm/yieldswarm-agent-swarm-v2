# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production DNS and crypto record map for YieldSwarm, Kairo, and treasury wallets.

> Apply these records in the **Unstoppable Domains dashboard** and/or **Cloudflare** (if used as resolver). This file is a runbook — it does not execute changes.

---

## 1. Domain inventory

| Domain (example) | Purpose | Primary target |
|------------------|---------|----------------|
| `yieldswarm.crypto` | Main marketing + swarm portal | Vercel `v2-0-bay.vercel.app` |
| `kairo.crypto` | Driver app (future) | Vercel Kairo deployment |
| `app.yieldswarm.crypto` | Authenticated app shell | Vercel |
| `api.yieldswarm.crypto` | Integration + telemetry API | Akash worker / backend |
| `dashboard.yieldswarm.crypto` | OpenClaw admin + Grafana | Akash or local monitoring |
| `odysseus.yieldswarm.crypto` | Odysseus orchestration API | Akash RTX 3090 lease |

Replace `.crypto` with your registered TLD (`.x`, `.nft`, etc.).

---

## 2. Website / frontend records (Path A — traditional DNS)

Recommended for Vercel + Akash hybrid hosting.

### Unstoppable Domains dashboard

| Host / record | Type | Value |
|---------------|------|-------|
| `@` (Website) | Website URL | `https://v2-0-bay.vercel.app` |
| `app` | CNAME | `cname.vercel-dns.com` (Vercel shows exact value) |
| `api` | CNAME | `<stable-akash-proxy-host>` (see §5) |
| `dashboard` | CNAME | `<monitoring-host>` or Vercel |
| `odysseus` | CNAME | `<akash-odysseus-endpoint>` |

### Vercel project domains

In Vercel → Project → Settings → Domains, add:

- `yieldswarm.crypto` (apex via UD web2 bridge or Cloudflare)
- `app.yieldswarm.crypto`
- `kairo.yieldswarm.crypto` (Kairo app when deployed)

### Cloudflare (optional resolver)

1. UD → domain → **Manage** → set Cloudflare nameservers.
2. Cloudflare zone → DNS:

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| CNAME | `app` | `cname.vercel-dns.com` | Proxied |
| CNAME | `api` | `<akash-proxy>` | Proxied |
| CNAME | `dashboard` | `<grafana-host>` | DNS only (or proxied) |
| CNAME | `odysseus` | `<akash-odysseus>` | Proxied |

TLS: **Full (strict)**. Enable HSTS after cert validation.

---

## 3. Crypto / treasury records

Set in UD → domain → **Crypto / Addresses**:

| Record | Example placeholder | Notes |
|--------|---------------------|-------|
| `crypto.ETH.address` | `0x…` (Gnosis Safe multisig) | EVM treasury |
| `crypto.SOL.address` | `…` (Squads multisig) | Solana treasury |
| `crypto.TON.address` | `EQ…` | TON treasury |
| `crypto.BTC.address` | `bc1…` | Optional BTC treasury |
| `crypto.MATIC.address` | `0x…` | Same as EVM if shared |

**Do not** put token mint addresses (e.g. `$APN` mint `8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump`) in wallet records — those are token contracts, not treasury wallets.

Verify every address character-by-character before signing the on-chain UD transaction.

---

## 4. Subdomain map (full stack)

```
yieldswarm.crypto          → Vercel (portal)
app.yieldswarm.crypto      → Vercel (React frontend + payments)
api.yieldswarm.crypto      → backend/src/server.js (Arena + Kairo proxy)
dashboard.yieldswarm.crypto → Grafana :3001 or OpenClaw dashboard
odysseus.yieldswarm.crypto → Odysseus + Ollama on Akash RTX 3090
kairo.yieldswarm.crypto    → Kairo driver app (Mapbox + 1% fee UX)
```

Backend routes once `api.` is wired:

| Path | Service |
|------|---------|
| `/api/arena/overview` | Arena telemetry |
| `/api/kairo/*` | Kairo driver identity + contributions |
| `/kairo/contribution.html` | Contribution dashboard |

---

## 5. Akash endpoint wiring

After `make akash-lease` or `scripts/akash-deploy.sh`:

1. Read worker URL from `.run/akash-lease.env` (`AKASH_WORKER_URLS`).
2. Place a **stable reverse proxy** (Cloudflare, nginx) in front — Akash provider URLs change on lease recreation.
3. Point `api.yieldswarm.crypto` CNAME at the stable proxy.
4. For Odysseus GPU workers, deploy `deploy/akash/odysseus.sdl.yml` and point `odysseus.` subdomain at that lease.

```bash
# Example after lease creation
source .run/akash-lease.env
echo "Point api.yieldswarm.crypto → ${AKASH_WORKER_URLS%%,*}"
```

---

## 6. Programmatic updates (Vault + UD API)

Store `UD_API_KEY` in HashiCorp Vault (`kv/data/yieldswarm/integrations/unstoppable`) — never commit.

```bash
source scripts/lib/vault-env.sh
vault_export_env kv/data/yieldswarm/integrations/unstoppable

curl -s "https://api.unstoppabledomains.com/resolve/domains/yieldswarm.crypto" \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

Docs: https://docs.unstoppabledomains.com/

---

## 7. Security

1. **Rotate** any UD API key that was ever committed to git history.
2. Store new keys only in Vault / Vercel env / GitHub Actions secrets.
3. Use multisig treasury addresses for all `crypto.*` records.
4. Audit UD dashboard for unauthorized record changes after key rotation.

---

## 8. Verification checklist

- [ ] `yieldswarm.crypto` resolves to Vercel frontend
- [ ] `app.` / `api.` / `dashboard.` / `odysseus.` subdomains resolve
- [ ] `kairo.` subdomain ready for driver app deploy
- [ ] `crypto.ETH`, `crypto.SOL`, `crypto.TON` verified with test micro-transfer
- [ ] HTTPS valid on all proxied hosts
- [ ] `curl https://api.yieldswarm.crypto/api/health` returns 200
- [ ] `curl https://api.yieldswarm.crypto/api/kairo/health` returns 200 (Kairo API up)
- [ ] Old UD API key revoked

---

## 9. Record this deployment

After wiring, update the table below with your live values:

| Record | Live value | Date |
|--------|------------|------|
| `app.yieldswarm.crypto` | | |
| `api.yieldswarm.crypto` | | |
| `crypto.ETH.address` | | |
| `crypto.SOL.address` | | |
| `crypto.TON.address` | | |
| Akash worker proxy | | |
| Odysseus GPU endpoint | | |
