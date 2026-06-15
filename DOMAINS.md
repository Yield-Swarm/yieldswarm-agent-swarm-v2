# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production wiring plan for pointing Unstoppable Domains at YieldSwarm / Kairo
infrastructure (Vercel frontend, Akash endpoints, API subdomains) and for
publishing treasury wallet records.

> This is a runbook. DNS and crypto records are set in the UD dashboard and/or
> Cloudflare — credentials stay in Vault, never in git.

---

## 0. Prerequisites

| Item | Where it comes from | Notes |
|------|--------------------|-------|
| Domain name(s) | Unstoppable Domains dashboard | e.g. `yieldswarm.crypto`, `kairo.x` |
| UD account | https://unstoppabledomains.com → My Domains | Wallet or email login |
| Vercel URL | Vercel dashboard | Current: `v2-0-bay.vercel.app` |
| Akash endpoint | `./scripts/deploy-production-vault-akash.sh` | `*.provider.*.akash.network` |
| Vault hostname | `SECRETS.md` | `vault.yieldswarm.io` |
| Treasury wallets | Multisig / Gnosis Safe | ETH, BTC, SOL, TON, IoTeX |

---

## 1. Domain → target map

| Record / subdomain | Target | Type | Purpose |
|--------------------|--------|------|---------|
| `@` (apex Website) | `https://v2-0-bay.vercel.app` | Website / redirect | Main YieldSwarm site |
| `app.` | Vercel (`cname.vercel-dns.com`) | CNAME | Kairo + payments app |
| `api.` | Akash worker or stable reverse proxy | CNAME / A | Backend API (`/api/kairo/*`) |
| `dashboard.` | Vercel or Akash OpenClaw admin | CNAME | Admin + telemetry |
| `vault.` | Vault server IP / internal | A (private) | HashiCorp Vault |
| `odysseus.` | Akash Odysseus SDL endpoint | CNAME | Agent workspace UI |
| `crypto.ETH.address` | Treasury EVM multisig | Crypto record | ETH / EVM treasury |
| `crypto.SOL.address` | Treasury Solana wallet | Crypto record | SOL treasury |
| `crypto.TON.address` | Treasury TON wallet | Crypto record | TON treasury |
| `crypto.BTC.address` | Treasury BTC address | Crypto record | BTC treasury |
| `crypto.IOTX.address` | IoTeX treasury (same key as EVM) | Crypto record | Kairo driver payouts |

`$APN` token mint: `8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump` — this is a
token mint, not a wallet. Do not use it in `crypto.SOL.address`.

---

## 2. Exact DNS records (Cloudflare path — recommended)

### Step 1: Delegate to Cloudflare

1. UD dashboard → domain → **Manage** → set custom nameservers to Cloudflare NS.
2. Cloudflare → Add site → copy the two NS values back into UD.

### Step 2: Cloudflare records

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| CNAME | `app` | `cname.vercel-dns.com` | Yes |
| CNAME | `api` | `<akash-worker-host>` or stable proxy | Yes |
| CNAME | `dashboard` | `cname.vercel-dns.com` | Yes |
| CNAME | `odysseus` | `<akash-odysseus-host>` | Yes |
| A | `vault` | `<vault-server-ip>` | No (internal) |

TLS: Cloudflare → SSL/TLS → **Full (strict)**.

### Step 3: Vercel custom domains

Vercel → Project → Settings → Domains:

```
app.yieldswarm.crypto
dashboard.yieldswarm.crypto
```

Vercel shows the exact CNAME to enter in Cloudflare/UD.

---

## 3. Unstoppable Domains dashboard (direct path)

If not using Cloudflare delegation:

1. UD → domain → **Website** → set redirect URL to `https://v2-0-bay.vercel.app`.
2. UD → **DNS / Records** → add CNAME rows for `app`, `api`, `dashboard`.
3. UD → **Crypto / Addresses** → add treasury addresses (see section 4).

---

## 4. Crypto (treasury) records

UD dashboard → domain → **Crypto / Addresses**:

| Ticker | Address source | Notes |
|--------|---------------|-------|
| ETH | `TREASURY_ETH_ADDRESS` in Vault | Gnosis Safe preferred |
| SOL | `TREASURY_SOL_ADDRESS` in Vault | Squads multisig preferred |
| TON | `TREASURY_TON_ADDRESS` in `.env.example` | TON Connect treasury |
| BTC | Treasury cold wallet | Verify char-by-char |
| IOTX | Same as EVM (IoTeX compatible) | Kairo driver identity chain |
| USDC | EVM treasury address | Same as ETH multisig |

Sign the on-chain UD transaction to persist. Verify with a small test transfer.

---

## 5. Akash endpoint wiring

After `./scripts/deploy-production-vault-akash.sh`:

```bash
source .run/akash-lease.env
echo $AKASH_WORKER_URI   # e.g. https://provider.akash.network:31337
```

1. Put a stable reverse proxy (Cloudflare or nginx) in front of the Akash URI.
2. Point `api.` CNAME at the stable host.
3. Health check: `curl -fsS $AKASH_WORKER_URI/healthz`

For Odysseus on Akash:

```bash
./scripts/deploy-production-odysseus.sh akash
# Point odysseus.<domain> at the returned URI
```

---

## 6. Kairo app subdomains

| Subdomain | Target | Purpose |
|-----------|--------|---------|
| `app.<domain>/kairo` | Vercel Next.js | Kairo driver dashboard |
| `app.<domain>/kairo/dashboard` | Contribution + rewards UI | DePIN telemetry |
| `app.<domain>/payments` | Payment rails | Square / Wise / Web3 |
| `api.<domain>/kairo/*` | Backend API routes | Driver identity, telemetry |

---

## 7. Programmatic updates (optional)

Store `UD_API_KEY` in Vault at `kv/data/yieldswarm/integrations/unstoppable-domains`.

```bash
vault kv get -field=UD_API_KEY kv/data/yieldswarm/integrations/unstoppable-domains

curl -s "https://api.unstoppabledomains.com/resolve/domains/yieldswarm.crypto" \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

Reference: https://docs.unstoppabledomains.com/

---

## 8. Security

1. **Never commit** `UD_API_KEY` — use Vault or Vercel env vars.
2. Rotate any key that was ever committed to git history.
3. Treasury addresses: verify first/last 6 characters after pasting.
4. Use multisig for all treasury crypto records.

---

## 9. Verification checklist

- [ ] UD Website record resolves to Vercel
- [ ] `app.` / `api.` / `dashboard.` / `odysseus.` resolve (dig + browser)
- [ ] `curl $AKASH_WORKER_URI/healthz` returns ok
- [ ] Crypto records verified; small test transfer ok
- [ ] HTTPS valid (no mixed content)
- [ ] `UD_API_KEY` only in Vault
- [ ] Kairo dashboard loads at `app.<domain>/kairo/dashboard`
