# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production wiring for YieldSwarm and Kairo domains: Vercel frontend, Akash API endpoints, treasury crypto records, and subdomains.

---

## Domain Inventory

| Domain | Purpose | Target |
|--------|---------|--------|
| `yieldswarm.crypto` | Main brand + treasury | Vercel + Akash |
| `kairo.crypto` | Driver marketplace app | Vercel (future Kairo app) |

---

## DNS Records

### Website / Frontend (Vercel)

| Record | Type | Value | Service |
|--------|------|-------|---------|
| `@` (apex) | Website URL | `https://v2-0-bay.vercel.app` | YieldSwarm main |
| `app` | CNAME | `cname.vercel-dns.com` | App frontend |
| `dashboard` | CNAME | `cname.vercel-dns.com` | OpenClaw admin |
| `kairo` | CNAME | `cname.vercel-dns.com` | Kairo driver app (future) |

**Vercel setup:** Project → Settings → Domains → add each subdomain. Copy the exact CNAME Vercel provides into Unstoppable Domains.

### API / Backend (Akash)

| Record | Type | Value | Service |
|--------|------|-------|---------|
| `api` | CNAME | `<stable-proxy>.yieldswarm.io` | Backend API (Akash lease behind proxy) |
| `odysseus` | CNAME | `<odysseus-lease>.akash.network` | Odysseus orchestration |
| `kairo-api` | CNAME | `<kairo-api-host>` | Kairo FastAPI (port 8092) |

> Put a stable reverse proxy (Cloudflare or nginx) in front of Akash leases so provider hostnames don't change on re-deploy.

### Crypto Treasury Records (Unstoppable Domains → Crypto Addresses)

| Record | Chain | Address placeholder |
|--------|-------|---------------------|
| `crypto.ETH.address` | Ethereum / EVM | `0x9505578Bd5b32468E3cEa632664F7b8d2e46128c` |
| `crypto.SOL.address` | Solana | `<treasury-solana-wallet>` |
| `crypto.TON.address` | TON | `<treasury-ton-wallet>` |
| `crypto.BTC.address` | Bitcoin | `<treasury-btc-wallet>` |

**$APN token mint** (public, not a wallet): `8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump`

Use a **multisig** (Gnosis Safe / Squads) for treasury records, not an EOA.

---

## Cloudflare Resolver (Recommended)

1. **Unstoppable Domains** → domain → Manage → DNS → set custom nameservers to Cloudflare NS.
2. **Cloudflare** → create zone → add records from tables above.
3. Enable proxy (orange cloud) + SSL **Full (strict)**.
4. Add Page Rules or Transform Rules for `api.*` → Akash proxy origin.

### Cloudflare DNS Template

```
app.yieldswarm.crypto       CNAME  cname.vercel-dns.com     (proxied)
dashboard.yieldswarm.crypto CNAME  cname.vercel-dns.com     (proxied)
api.yieldswarm.crypto       CNAME  akash-proxy.yieldswarm.io (proxied)
kairo.yieldswarm.crypto     CNAME  cname.vercel-dns.com     (proxied)
kairo-api.yieldswarm.crypto CNAME  akash-proxy.yieldswarm.io (proxied)
```

---

## Unstoppable Domains Dashboard Steps

### Website record
1. UD dashboard → My Domains → select domain → **Website**
2. Enter `https://v2-0-bay.vercel.app` (or IPFS CID for dweb path)
3. Save and sign the on-chain transaction

### Crypto records
1. Domain → **Crypto Addresses**
2. Add ETH, SOL, TON, BTC treasury addresses
3. Verify first/last 4 characters after paste
4. Sign on-chain transaction

### Subdomains (Path A — traditional DNS)
1. Domain → **DNS / Records**
2. Add CNAME rows from tables above
3. Wait for propagation (up to 24h)

---

## Programmatic Updates (UD API)

Store `UD_API_KEY` in Vault at `yieldswarm/data/integrations/ud` (seeded by `vault/setup/05-seed-secrets.sh`).

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<operator-token>
export UD_API_KEY=$(vault kv get -field=api_key yieldswarm/integrations/ud)

curl -s "https://api.unstoppabledomains.com/resolve/domains/yieldswarm.crypto" \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

Docs: https://docs.unstoppabledomains.com/

---

## Verification Checklist

- [ ] `yieldswarm.crypto` Website record → Vercel deployment
- [ ] `app.` / `api.` / `dashboard.` subdomains resolve (`dig +short`)
- [ ] Crypto records verified character-by-character
- [ ] HTTPS valid on all proxied endpoints
- [ ] `UD_API_KEY` rotated if previously exposed; stored only in Vault
- [ ] Kairo subdomains wired when Kairo app deploys to Vercel

---

## Security

- **Never commit** `UD_API_KEY` — use Vault path `yieldswarm/data/integrations/ud`
- Rotate compromised keys immediately via UD dashboard
- Treasury addresses require multisig + test transfer before publishing
