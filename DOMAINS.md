# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production wiring for YieldSwarm and Kairo on Unstoppable Domains, Vercel,
Akash, and Cloudflare.

> This is a runbook — DNS and UD records are applied in the UD dashboard and
> your DNS provider. Credentials never belong in this repo.

---

## 0. Prerequisites

| Item | Source | Current value |
|------|--------|---------------|
| Primary domain | UD dashboard | `yieldswarm.crypto` (example) |
| Kairo app domain | UD dashboard | `kairo.x` or `app.yieldswarm.crypto` |
| Vercel frontend | Vercel dashboard | `v2-0-bay.vercel.app` |
| Akash worker | After deploy | from `.run/akash-lease.env` → `AKASH_WORKER_URLS` |
| Odysseus API | After deploy | Akash port 81 or `localhost:7000` (staging) |
| Treasury ETH/EVM | Multisig | `0x9505578Bd5b32468E3cEa632664F7b8d2e46128c` (mining wallet ref) |
| Treasury SOL | Squads/multisig | your ops wallet (not the `$APN` mint) |
| Treasury TON | TON wallet | your ops wallet |
| UD API key | UD → Profile → API | store in Vault as `UD_API_KEY` |

`$APN` mint (public): `8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump` — token mint only.

---

## 1. Recommended record map

| Host / record | Type | Target | Purpose |
|---------------|------|--------|---------|
| `@` | Website URL | `https://v2-0-bay.vercel.app` | Marketing / landing |
| `app` | CNAME | `cname.vercel-dns.com` | YieldSwarm + Payments UI |
| `kairo` | CNAME | `cname.vercel-dns.com` | Kairo driver app (`/kairo`) |
| `api` | CNAME | Akash stable proxy host | Next.js API + backend |
| `odysseus` | CNAME | Akash Odysseus URI (port 81) | Agent orchestration |
| `dashboard` | CNAME | Vercel or Akash | OpenClaw admin |
| `telemetry` | CNAME | Prometheus/Grafana host | Ops monitoring |
| `crypto.ETH.address` | Crypto | Treasury EVM multisig | Wallet resolution |
| `crypto.SOL.address` | Crypto | Treasury SOL wallet | Wallet resolution |
| `crypto.TON.address` | Crypto | Treasury TON wallet | Wallet resolution |
| `crypto.MATIC.address` | Crypto | Polygon treasury (optional) | Wallet resolution |
| `ipfs.html.value` | IPFS | CID of static build | dweb fallback |

---

## 2. Path A — Cloudflare + traditional DNS (recommended)

### Step 1: Delegate to Cloudflare

1. Create a zone in Cloudflare for your UD domain (if using web2 bridge).
2. In **Unstoppable Domains** → domain → **Manage** → set custom nameservers to Cloudflare NS.

### Step 2: Cloudflare DNS records

```
app.yieldswarm.crypto     CNAME   cname.vercel-dns.com     (proxied)
kairo.yieldswarm.crypto   CNAME   cname.vercel-dns.com     (proxied)
api.yieldswarm.crypto     CNAME   <akash-stable-proxy>     (proxied)
odysseus.yieldswarm.crypto CNAME  <akash-odysseus-host>    (DNS only)
dashboard.yieldswarm.crypto CNAME cname.vercel-dns.com     (proxied)
```

TLS: **Full (strict)**. Enable HSTS after verifying certs.

### Step 3: Vercel custom domains

Vercel → Project `v2-0` → Settings → Domains:

- `app.yieldswarm.crypto`
- `kairo.yieldswarm.crypto`
- `dashboard.yieldswarm.crypto`

Copy the exact CNAME targets Vercel shows into Cloudflare.

### Step 4: Akash stable proxy

Akash lease URIs change when leases move. Put nginx/Caddy/Cloudflare Tunnel in front:

```bash
# After: make akash-lease
source .run/akash-lease.env
echo "Point api.* CNAME at reverse proxy → ${AKASH_WORKER_URLS%%,*}"
```

Document your stable proxy hostname here once provisioned:

```
AKASH_STABLE_API_HOST=api-proxy.yieldswarm.io   # <-- fill after setup
```

---

## 3. Path B — Decentralized (IPFS)

1. `npm run build && npx vercel build` or export static `out/`.
2. Pin to IPFS (Pinata / web3.storage / Filecoin).
3. UD dashboard → **Website** → paste IPFS CID.
4. Optional: set `ipfs.html.value` redirect record.

---

## 4. Crypto treasury records (UD dashboard)

Unstoppable Domains → domain → **Crypto Addresses**:

| Ticker | Record key | Value |
|--------|------------|-------|
| ETH | `crypto.ETH.address` | `<treasury-evm-multisig>` |
| SOL | `crypto.SOL.address` | `<treasury-sol-wallet>` |
| TON | `crypto.TON.address` | `<treasury-ton-wallet>` |
| BTC | `crypto.BTC.address` | `<treasury-btc-wallet>` (optional) |
| MATIC | `crypto.MATIC.address` | `<treasury-polygon>` (optional) |

Verify first/last 4 characters after paste. Sign the on-chain UD transaction to persist.

---

## 5. Kairo-specific subdomains

| Subdomain | Target | Notes |
|-----------|--------|-------|
| `kairo.app.<domain>` | Vercel | Future standalone Kairo PWA |
| `drivers.<domain>` | Same as `kairo` | Driver onboarding |
| `telemetry.kairo.<domain>` | API gateway | Signed telemetry ingest (`POST /api/kairo/telemetry`) |

Mapbox tiles and driver GPS use the Kairo app origin — ensure CORS allows your API host.

---

## 6. Programmatic updates (Vault + UD API)

Store `UD_API_KEY` in Vault path `kv/data/yieldswarm/integrations/unstoppable`.

```bash
# Load from Vault at runtime — never commit the key
. scripts/lib/vault-env.sh
vault_export_env kv/data/yieldswarm/integrations/unstoppable

curl -s "https://api.unstoppabledomains.com/resolve/domains/${DOMAIN}" \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

Docs: https://docs.unstoppabledomains.com/

---

## 7. Post-deploy verification

```bash
# DNS
dig app.yieldswarm.crypto CNAME +short
dig api.yieldswarm.crypto CNAME +short

# HTTPS
curl -fsSI https://app.yieldswarm.crypto | head -5
curl -fsS https://api.yieldswarm.crypto/api/config

# Akash worker (replace host)
curl -fsS "https://${AKASH_HOST}/healthz"

# Odysseus
curl -fsS "https://odysseus.yieldswarm.crypto/healthz" | jq .

# Kairo telemetry (staging)
curl -fsS -X POST https://app.yieldswarm.crypto/api/kairo/drivers/register
```

Checklist:

- [ ] UD Website record → Vercel or IPFS
- [ ] `app.` / `kairo.` / `api.` / `dashboard.` resolve
- [ ] Crypto records verified; test micro-transfer
- [ ] HTTPS valid (no mixed content)
- [ ] `UD_API_KEY` rotated if ever exposed; key only in Vault
- [ ] This file updated with your live domain names and proxy hosts

---

## 8. Security

1. **Rotate** any `UD_API_KEY` that appeared in git history — use Vault only.
2. Treasury records → **multisig**, never hot EOA.
3. Akash Ollama endpoints → private overlay (Tailscale/WireGuard), not public.
4. Webhook URLs (`api.*/api/webhooks/square`) → HTTPS only, verify signatures.

See [`SECRETS.md`](SECRETS.md) for Vault paths and rotation policy.
