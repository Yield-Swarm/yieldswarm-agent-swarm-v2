# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Complete production runbook: wire **all 17 Unstoppable Domains** and subdomains
to **Vercel** (frontend) and **Akash** (API / workers / telemetry).

| Target | Current value | After Akash deploy |
|--------|---------------|-------------------|
| Vercel project | `v2-0` | same |
| Vercel URL | `https://v2-0-bay.vercel.app` | custom domains replace this |
| Vercel CNAME | `cname.vercel-dns.com` | confirm in Vercel → Domains |
| Akash stable gateway | *(set up in §4)* | `gateway.yieldswarm.crypto` |
| Akash worker URI | *(from deploy)* | see `.run/akash-lease.env` |

> Credentials (`UD_API_KEY`, treasury wallets) live in **Vault** or local `.env`
> only — never commit to this repo.

---

## 1. Architecture

```
                    ┌─────────────────────────────────────┐
                    │     Unstoppable Domains (17 names)   │
                    │  Website + DNS + crypto.* records    │
                    └──────────────┬──────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
     ┌────────────────┐  ┌───────────────┐  ┌─────────────────┐
     │ Vercel (HTTPS) │  │ Cloudflare    │  │ UD crypto       │
     │ app/www/...    │  │ gateway.*     │  │ ETH/BTC/SOL     │
     └────────────────┘  └───────┬───────┘  └─────────────────┘
                                 │
                                 ▼
                    ┌────────────────────────┐
                    │ Akash (DePIN workers)  │
                    │ api / arena / odysseus │
                    │ RTX 3090 monolith      │
                    └────────────────────────┘
```

**Routing rule**

| Subdomain pattern | Points to | Used for |
|-------------------|-----------|----------|
| `@`, `www`, `app` | Vercel | Web UI, Kairo, marketplace |
| `api`, `worker`, `rpc` | Akash gateway | REST, healthz, Kairo API |
| `dashboard`, `status`, `vault` | Vercel | Static dashboards |
| `arena`, `telemetry`, `odysseus` | Akash gateway | Live metrics, agents |
| `grafana`, `metrics` | Akash gateway | Prometheus / Grafana |

---

## 2. Master subdomain standard (apply to every domain)

Use this **exact subdomain set** on each of the 17 domains. Only the apex
**Website** path differs per domain (see §5).

| Host | Type | Target (Phase 1 — Vercel now) | Target (Phase 2 — Akash live) |
|------|------|-------------------------------|-------------------------------|
| `@` | Website | `https://v2-0-bay.vercel.app` + path | same or production URL |
| `www` | CNAME | `cname.vercel-dns.com` | `cname.vercel-dns.com` |
| `app` | CNAME | `cname.vercel-dns.com` | `cname.vercel-dns.com` |
| `api` | CNAME | `gateway.yieldswarm.crypto` | `gateway.yieldswarm.crypto` |
| `worker` | CNAME | `gateway.yieldswarm.crypto` | `gateway.yieldswarm.crypto` |
| `dashboard` | CNAME | `cname.vercel-dns.com` | `cname.vercel-dns.com` |
| `status` | CNAME | `cname.vercel-dns.com` | `cname.vercel-dns.com` |
| `arena` | CNAME | `gateway.yieldswarm.crypto` | `gateway.yieldswarm.crypto` |
| `telemetry` | CNAME | `gateway.yieldswarm.crypto` | `gateway.yieldswarm.crypto` |
| `odysseus` | CNAME | `gateway.yieldswarm.crypto` | `gateway.yieldswarm.crypto` |
| `grafana` | CNAME | `gateway.yieldswarm.crypto` | `gateway.yieldswarm.crypto` |
| `gateway` | CNAME | *(Akash provider host — §4)* | stable proxy origin |

**TTL:** `300` for all DNS records.

**Vercel apex (@):** In Cloudflare (recommended), use CNAME flattening to
`cname.vercel-dns.com` **or** A records `76.76.21.21` per
[Vercel custom domain docs](https://vercel.com/docs/projects/domains).

---

## 3. Domain registry — all 17 domains, exact targets

### 3a. Primary product (6)

| # | Domain | Apex Website URL | Vercel path | Akash service |
|---|--------|------------------|-------------|---------------|
| 1 | `yieldswarm.crypto` | `https://v2-0-bay.vercel.app` | `/` | `api` → monolith `/healthz` |
| 2 | `yieldswarm.x` | `https://v2-0-bay.vercel.app` | `/` | `api` → monolith |
| 3 | `kairo.x` | `https://v2-0-bay.vercel.app/kairo` | `/kairo` | `api` → Kairo `:8787` |
| 4 | `kairo.crypto` | `https://v2-0-bay.vercel.app/kairo` | `/kairo` | `api` → Kairo |
| 5 | `helixchain.crypto` | `https://v2-0-bay.vercel.app` | `/` | `rpc` → Helix RPC |
| 6 | `agentswarm.crypto` | `https://v2-0-bay.vercel.app` | `/` | `worker` → agent mesh |

### 3b. Treasury & token (3)

| # | Domain | Apex Website | Crypto records (all domains) |
|---|--------|--------------|------------------------------|
| 7 | `yieldswarm.wallet` | `https://v2-0-bay.vercel.app` | ETH, BTC, SOL, MATIC, USDC |
| 8 | `apn.crypto` | `https://v2-0-bay.vercel.app` | SOL treasury only |
| 9 | `yslr.crypto` | `https://v2-0-bay.vercel.app` | ETH + SOL treasury |

### 3c. DePIN & marketplace (4)

| # | Domain | Apex Website URL | Vercel route |
|---|--------|------------------|--------------|
| 10 | `depin.crypto` | `https://v2-0-bay.vercel.app/marketplace` | `/marketplace` |
| 11 | `z15.crypto` | `https://v2-0-bay.vercel.app/sales` | `/sales` |
| 12 | `openclaw.crypto` | `https://v2-0-bay.vercel.app/dashboard` | `/dashboard` |
| 13 | `odysseus.crypto` | `https://v2-0-bay.vercel.app` | Akash `odysseus` subdomain |

### 3d. Council & arena (3)

| # | Domain | Apex Website URL | Vercel route |
|---|--------|------------------|--------------|
| 14 | `council.crypto` | `https://v2-0-bay.vercel.app/council/status` | `/council/status` |
| 15 | `arena.crypto` | `https://v2-0-bay.vercel.app/arena` | `/arena` + Akash telemetry |
| 16 | `kimiclaw.crypto` | `https://v2-0-bay.vercel.app` | Akash consensus API |

### 3e. Reserve (1)

| # | Domain | Apex Website | Notes |
|---|--------|--------------|-------|
| 17 | `staging.yieldswarm.crypto`* | `https://v2-0-bay.vercel.app` | Preview / CI; replace with your 17th UD name |

\*If your 17th domain has a different name, keep the same DNS rows from §2.

---

## 4. Setup steps — do these in order

### Step A — Unstoppable Domains (every domain)

For **each** of the 17 domains:

1. Go to [https://unstoppabledomains.com](https://unstoppabledomains.com) → **My Domains**.
2. Click the domain → **Manage** → **Website**.
3. Set **Website** to the **Apex Website URL** from §3 (e.g. `https://v2-0-bay.vercel.app`).
4. Open **DNS Records** (or **Manage DNS**).
5. Add every row from §2 (Phase 1 targets).
6. Open **Crypto Addresses** → add treasury records from §6.
7. Sign the on-chain transaction when prompted (gas required).

**Primary domain first:** complete `yieldswarm.crypto` end-to-end, then clone
records to the other 16 domains (change only apex Website path where §3 differs).

### Step B — Vercel custom domains

Project: `v2-0` → **Settings** → **Domains** → Add each hostname:

```text
# yieldswarm.crypto
yieldswarm.crypto
www.yieldswarm.crypto
app.yieldswarm.crypto
dashboard.yieldswarm.crypto
status.yieldswarm.crypto

# yieldswarm.x
yieldswarm.x
www.yieldswarm.x
app.yieldswarm.x

# kairo
kairo.x
app.kairo.x
kairo.crypto
app.kairo.crypto

# product
agentswarm.crypto
app.agentswarm.crypto
helixchain.crypto

# marketplace
depin.crypto
z15.crypto
openclaw.crypto
dashboard.openclaw.crypto

# council
council.crypto
arena.crypto

# treasury TLDs (apex only)
yieldswarm.wallet
apn.crypto
yslr.crypto
odysseus.crypto
kimiclaw.crypto
```

Vercel shows the **exact CNAME** per domain — if it differs from
`cname.vercel-dns.com`, use Vercel's value in UD DNS.

Enable **Redirect** where offered: `www` → apex, `http` → `https`.

### Step C — Cloudflare gateway (recommended for Akash + `.crypto` resolution)

Do this once on `yieldswarm.crypto`; repeat NS delegation for other domains.

1. **Cloudflare** → Add site → `yieldswarm.crypto`.
2. Copy nameservers (e.g. `ada.ns.cloudflare.com`, `bob.ns.cloudflare.com`).
3. **UD** → `yieldswarm.crypto` → **Nameservers** → paste Cloudflare NS.
4. In **Cloudflare DNS**, create all §2 records (Vercel + gateway CNAMEs).
5. **SSL/TLS** → **Full (strict)**.
6. Enable **Proxied** (orange cloud) on `app`, `www`, `api`, `gateway`.
7. Create a **Cloudflare Worker** (or Transform Rule) for `gateway.yieldswarm.crypto`:

```javascript
// workers/gateway.js — route api.* to Akash worker backend
export default {
  async fetch(request, env) {
    const backend = env.AKASH_WORKER_URL; // from .run/akash-lease.env
    const url = new URL(request.url);
    url.hostname = new URL(backend).hostname;
    url.protocol = new URL(backend).protocol;
    return fetch(new Request(url, request));
  },
};
```

Set Worker secret `AKASH_WORKER_URL` after deploy (e.g. `https://provider-host.akash.network`).

8. Point **`gateway`** CNAME at the Worker route, or A record to Worker IP.

**Why:** Akash provider hostnames change when leases move. The gateway stays
fixed; you only update the Worker backend when re-deploying.

### Step D — Deploy Akash and wire gateway

```bash
cp deploy/akash.env.example deploy/akash.env
./scripts/deploy-to-akash.sh deploy

# Capture worker URL
source .run/akash-lease.env
echo "$AKASH_WORKER_URLS"
```

Update Cloudflare Worker `AKASH_WORKER_URL` to the first HTTPS URI from deploy
output. Then verify:

```bash
curl -sf "https://api.yieldswarm.crypto/healthz"
curl -sf "https://gateway.yieldswarm.crypto/healthz"
```

### Step E — Map Akash services to subdomains

After gateway is live, these resolve to Akash (via `gateway.yieldswarm.crypto`):

| Public hostname | Backend path / port | Akash SDL |
|-----------------|---------------------|-----------|
| `api.yieldswarm.crypto` | `/healthz`, REST API | `deploy/deploy-swarm-monolith.yaml` |
| `api.kairo.x` | Kairo API `/api/*` | sidecar `:8787` |
| `arena.crypto` | Arena telemetry | `akash/telemetry/` |
| `odysseus.crypto` | Odysseus `:8080` | `deploy/akash/odysseus.sdl.yml` |
| `telemetry.yieldswarm.crypto` | Prometheus scrape | `deploy/monitoring/` |
| `grafana.yieldswarm.crypto` | Grafana `:3001` | monitoring stack |

---

## 5. Per-domain exact DNS tables

Copy-paste blocks for UD dashboard or Cloudflare. Replace only the **apex Website**
per §3.

### `yieldswarm.crypto` (canonical — set up first)

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| Website | `@` | `https://v2-0-bay.vercel.app` | — |
| CNAME | `www` | `cname.vercel-dns.com` | Yes |
| CNAME | `app` | `cname.vercel-dns.com` | Yes |
| CNAME | `dashboard` | `cname.vercel-dns.com` | Yes |
| CNAME | `status` | `cname.vercel-dns.com` | Yes |
| CNAME | `api` | `gateway.yieldswarm.crypto` | Yes |
| CNAME | `worker` | `gateway.yieldswarm.crypto` | Yes |
| CNAME | `arena` | `gateway.yieldswarm.crypto` | Yes |
| CNAME | `telemetry` | `gateway.yieldswarm.crypto` | Yes |
| CNAME | `odysseus` | `gateway.yieldswarm.crypto` | Yes |
| CNAME | `grafana` | `gateway.yieldswarm.crypto` | Yes |
| CNAME | `gateway` | `<AKASH_PROVIDER_HOST>` | Yes |

### `kairo.x` / `kairo.crypto`

| Type | Name | Content |
|------|------|---------|
| Website | `@` | `https://v2-0-bay.vercel.app/kairo` |
| CNAME | `app` | `cname.vercel-dns.com` |
| CNAME | `api` | `gateway.yieldswarm.crypto` |

Add to **Vercel** env (Project → Settings → Environment Variables):

| Variable | Value |
|----------|-------|
| `KAIRO_API_BASE` | `https://api.kairo.x` |
| `MAPBOX_TOKEN` | from Vault `yieldswarm/integrations/mapbox` |

### `depin.crypto` / `z15.crypto` / `council.crypto`

| Domain | Website `@` |
|--------|-------------|
| `depin.crypto` | `https://v2-0-bay.vercel.app/marketplace` |
| `z15.crypto` | `https://v2-0-bay.vercel.app/sales` |
| `council.crypto` | `https://v2-0-bay.vercel.app/council/status` |

Plus standard §2 subdomains (`app` → Vercel, `api` → gateway).

### Remaining domains (12–17)

For `yieldswarm.x`, `agentswarm.crypto`, `helixchain.crypto`, `apn.crypto`,
`yslr.crypto`, `openclaw.crypto`, `odysseus.crypto`, `arena.crypto`,
`kimiclaw.crypto`, `yieldswarm.wallet`:

1. Set **Website** from §3.
2. Add full §2 subdomain set unchanged.
3. Add domain apex + `app` to Vercel if it serves a web UI.

---

## 6. Crypto (treasury) records — set on ALL payment domains

Set in UD → **Crypto Addresses** for domains 1, 7, 8, 9 (and optionally all 17).

| Record key | Example placeholder | Notes |
|------------|---------------------|-------|
| `crypto.ETH.address` | `0xYOUR_GNOSIS_SAFE` | EVM treasury |
| `crypto.BTC.address` | `bc1YOUR_BTC_MULTISIG` | Bitcoin treasury |
| `crypto.SOL.address` | `YOUR_SQUADS_PUBKEY` | Solana treasury |
| `crypto.MATIC.address` | `0xYOUR_GNOSIS_SAFE` | Polygon (same as ETH OK) |
| `crypto.USDC.address` | `0xYOUR_USDC_RECEIVER` | Optional |

**Do not** use the `$APN` mint as a wallet:
`8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump` is a **token mint**, not treasury.

Verify first/last 4 characters after paste. Sign on-chain to persist.

---

## 7. Vercel routes (repo `vercel.json`)

These paths must work before custom domains go live:

| Path | Serves |
|------|--------|
| `/` | Next.js app (`src/app/`) |
| `/kairo` | `kairo/frontend/index.html` |
| `/payments` | Payment rails |
| `/arena` | Arena dashboard |
| `/council/*` | Council status HTML |
| `/dashboard/*` | Sovereign / vault dashboards |

Test on preview URL before switching apex Website records:

```bash
curl -sI https://v2-0-bay.vercel.app/kairo | head -1
curl -sI https://v2-0-bay.vercel.app/council/status | head -1
```

---

## 8. Akash endpoint reference

| Deploy command | Output file | Use in DNS |
|----------------|-------------|------------|
| `./scripts/deploy-to-akash.sh deploy` | `.run/akash-lease.env` | `AKASH_WORKER_URLS` → gateway backend |
| `./scripts/deploy-to-akash.sh health` | JSON with URIs | confirm `/healthz` |
| `akash/lease-manager.py` | auto-failover | update gateway on provider change |

**SDL → port mapping**

| Service | SDL | External port | Health |
|---------|-----|---------------|--------|
| Swarm monolith | `deploy/deploy-swarm-monolith.yaml` | 80 → 8080 | `/healthz` |
| GPU worker | `akash/worker.sdl.yml` | 80, 9090 | `/healthz` |
| Odysseus | `deploy/akash/odysseus.sdl.yml` | 8080 | `/healthz` |
| Kairo API | runtime sidecar | 8787 | `/healthz` |

---

## 9. Programmatic updates (UD API)

Store `UD_API_KEY` in Vault (`yieldswarm/integrations/ud`). Load from `.env` locally.

```bash
export UD_API_KEY="$(vault kv get -field=api_key yieldswarm/integrations/ud)"

# Verify resolution
curl -s "https://api.unstoppabledomains.com/resolve/domains/yieldswarm.crypto" \
  -H "Authorization: Bearer ${UD_API_KEY}" | jq .
```

API docs: https://docs.unstoppabledomains.com/

Rotate keys in UD dashboard if ever committed to git. Current key name in UD:
**Cursor api key** (keep one production key in Vault only).

---

## 10. Verification checklist

### Phase 1 — Vercel (can do tonight)

- [ ] `yieldswarm.crypto` Website → `https://v2-0-bay.vercel.app`
- [ ] `app.yieldswarm.crypto` → Vercel, valid HTTPS (green lock)
- [ ] `kairo.x` Website → `/kairo` path loads Mapbox UI
- [ ] `depin.crypto`, `z15.crypto`, `council.crypto` apex paths correct
- [ ] All Vercel domains show **Valid Configuration**
- [ ] Crypto records signed on-chain for treasury domains
- [ ] `UD_API_KEY` in Vault only; unused UD keys revoked

### Phase 2 — Akash (after deploy)

- [ ] `./scripts/deploy-to-akash.sh deploy` succeeds
- [ ] `gateway.yieldswarm.crypto` Worker points at `AKASH_WORKER_URLS`
- [ ] `curl -sf https://api.yieldswarm.crypto/healthz` → 200
- [ ] `curl -sf https://api.kairo.x/healthz` or Kairo API responds
- [ ] `arena.crypto` / `telemetry.*` show live Akash metrics
- [ ] Update `DOMAINS.md` §3 row 17 with your actual 17th domain name

---

## 11. Quick diagnostic commands

```bash
# DNS propagation
dig app.yieldswarm.crypto CNAME +short
dig api.yieldswarm.crypto CNAME +short
dig gateway.yieldswarm.crypto CNAME +short

# Vercel
vercel domains ls

# Akash lease
source .run/akash-lease.env
./scripts/deploy-to-akash.sh status "$AKASH_DSEQ" "$AKASH_PROVIDER"

# End-to-end health
for host in api.yieldswarm.crypto api.kairo.x gateway.yieldswarm.crypto; do
  echo -n "$host: "; curl -sf -o /dev/null -w "%{http_code}\n" "https://$host/healthz" || echo FAIL
done
```

---

## 12. Related docs

| Doc | Topic |
|-----|-------|
| `docs/AKASH_DEPLOY.md` | Akash deploy + JWT auth |
| `KAIRO_FRONTEND.md` | Kairo Vercel + Mapbox |
| `SECRETS.md` | Vault + `UD_API_KEY` |
| `vercel.json` | Route definitions |
