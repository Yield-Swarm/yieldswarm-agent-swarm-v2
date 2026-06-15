# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production wiring for Unstoppable Domains → YieldSwarm / Kairo infrastructure
(Vercel frontend, Akash API, treasury crypto records).

> **Scope:** Runbook only. Apply records in the UD dashboard and/or Cloudflare.
> Store `UD_API_KEY` in Vault at `yieldswarm/integrations/unstoppable`.

---

## 0. Prerequisites

| Item | Source | Notes |
|------|--------|-------|
| Domain(s) | UD dashboard | e.g. `yieldswarm.crypto`, `kairo.x` |
| Vercel URL | Vercel dashboard | `v2-0-bay.vercel.app` (see `README.md`) |
| Akash API | After Vault deploy | `scripts/akash-deploy-with-vault.sh` |
| Treasury wallets | Multisig | ETH, BTC, SOL, TON |
| UD API key | Vault `yieldswarm/integrations/unstoppable` | Never commit |

**Current repo assets:** `deploy/deploy-swarm-monolith.yaml`, `deploy/akash/*`,
`terraform/`, `backend/` integration server, `kairo/dashboard/`.

---

## 1. Domain → target map

| Record / subdomain | Target | Type | Purpose |
|--------------------|--------|------|---------|
| `@` (apex Website) | `https://v2-0-bay.vercel.app` | Website URL | Main YieldSwarm app |
| `app.<domain>` | Vercel deployment | CNAME | App frontend |
| `api.<domain>` | Akash worker / `backend:8787` | CNAME / A | Telemetry + Kairo API |
| `dashboard.<domain>` | OpenClaw admin | CNAME | Admin dashboard |
| `kairo.<domain>` | Vercel (future Kairo app) | CNAME | Driver marketplace |
| `crypto.ETH.address` | Treasury EVM multisig | Crypto record | Wallet resolution |
| `crypto.SOL.address` | Treasury Solana | Crypto record | Wallet resolution |
| `crypto.TON.address` | Treasury TON | Crypto record | Wallet resolution |
| `crypto.BTC.address` | Treasury BTC | Crypto record | Wallet resolution |

`$APN` mint (`8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump`) is a **token mint**,
not a wallet — do not use it in `crypto.SOL.address`.

---

## 2. Resolution paths

### Path A — Traditional DNS (recommended)

1. UD dashboard → domain → **DNS / Records**.
2. Add `CNAME` for `app` → Vercel target (from Vercel → Domains settings).
3. Add `CNAME` for `api` → stable reverse proxy in front of Akash worker.
4. (Recommended) Delegate to **Cloudflare**:
   - UD: set Cloudflare nameservers.
   - Cloudflare zone: add `A`/`CNAME` records, enable proxy + Full (strict) TLS.

### Path B — Decentralized (IPFS)

1. Build static site → upload to IPFS (Pinata / web3.storage).
2. UD dashboard → **Website** → paste IPFS CID.
3. Verify: `https://<CID>.ipfs.dweb.link`

---

## 3. Subdomain wiring

| Subdomain | Service | Port | Notes |
|-----------|---------|------|-------|
| `app.` | Vercel Next.js | 443 | Auto TLS via Vercel |
| `api.` | Backend integration server | 8787 | `/api/*`, `/api/kairo/*` |
| `dashboard.` | OpenClaw / Grafana | 443 | `deploy/monitoring/` stack |
| `kairo.` | Kairo driver app (future) | 443 | Shares payment rails + wallet |

---

## 4. Crypto treasury records

UD dashboard → domain → **Crypto / Addresses**:

| Ticker | Record path | Example |
|--------|-------------|---------|
| ETH | `crypto.ETH.address` | `0x9505578Bd5b32468E3cEa632664F7b8d2e46128c` |
| SOL | `crypto.SOL.address` | Treasury Squads multisig |
| TON | `crypto.TON.address` | Treasury TON wallet |
| BTC | `crypto.BTC.address` | Treasury BTC multisig |

Verify first/last 4 characters after paste. Prefer multisig over EOA.

---

## 5. Akash endpoint wiring

After `scripts/akash-deploy-with-vault.sh`:

```bash
# 1. Get lease endpoint
provider-services lease-status --dseq <DSEQ> --from <KEY>

# 2. Put stable reverse proxy in front (Cloudflare or nginx)
# 3. Point api.<domain> CNAME at proxy host
# 4. Backend routes:
#    GET  https://api.<domain>/api/arena/overview
#    POST https://api.<domain>/api/kairo/telemetry/ingest
```

Document live provider host here once deployed:

```
api.yieldswarm.crypto → <PROVIDER_HOST>:<PORT>
```

---

## 6. Cloudflare resolver (if used)

1. UD → custom nameservers → Cloudflare NS values.
2. Cloudflare zone records:

| Name | Type | Content | Proxy |
|------|------|---------|-------|
| `app` | CNAME | `cname.vercel-dns.com` | Yes |
| `api` | CNAME | `<akash-proxy-host>` | Yes |
| `dashboard` | CNAME | `<monitoring-host>` | Yes |
| `kairo` | CNAME | `cname.vercel-dns.com` | Yes |

3. SSL/TLS → Full (strict).

---

## 7. Programmatic updates (UD API)

```bash
# UD_API_KEY from Vault — never from repo
export UD_API_KEY="$(vault kv get -field=api_key yieldswarm/integrations/unstoppable)"

curl -s "https://api.unstoppabledomains.com/resolve/domains/<yourdomain>" \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

Docs: https://docs.unstoppabledomains.com/

---

## 8. Security

1. **Rotate** any `UD_API_KEY` previously committed to git history.
2. Store new key only in Vault / Vercel env / GitHub Actions secrets.
3. Treasury addresses should be multisig — update UD records when rotating.

---

## 9. Verification checklist

- [ ] `app.<domain>` loads Vercel frontend over HTTPS
- [ ] `api.<domain>/api/health` returns `200`
- [ ] `api.<domain>/api/kairo/health` returns `200`
- [ ] `crypto.ETH.address` resolves in UD resolver
- [ ] `kairo.<domain>` placeholder or Vercel preview loads
- [ ] Cloudflare proxy enabled with Full (strict) TLS
