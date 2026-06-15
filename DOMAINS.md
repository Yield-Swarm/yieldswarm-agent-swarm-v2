# YieldSwarm Domain Configuration

Complete DNS wiring for Unstoppable Domains + Cloudflare resolver.

**Primary domain:** `yieldswarm.crypto` (Unstoppable Domains)

---

## Overview

| Subdomain | Purpose | Target |
|-----------|---------|--------|
| `@` / `www` | Marketing site + v2 dashboard | Vercel |
| `app` | Kairo driver/customer app | Vercel (future) / Expo |
| `api` | Production API gateway | Akash ingress |
| `api-testnet` | Testnet API | Akash testnet lease |
| `dashboard` | $5M telemetry + OpenClaw admin | Vercel |
| `vault` | HashiCorp Vault (private) | HCP Vault / self-hosted |
| `odysseus` | Direct Odysseus orchestrator (internal) | Akash private |
| `council` | DAO status page | Vercel / static |

---

## Treasury Wallet Records (Unstoppable Domains)

Configure in **Unstoppable Domains Dashboard → My Domains → yieldswarm.crypto → Crypto Addresses**.

| TLD Record | Chain | Address | Purpose |
|------------|-------|---------|---------|
| `crypto.ETH` | Ethereum | `0x9505578Bd5b32468E3cEa632664F7b8d2e46128c` | Primary EVM treasury |
| `crypto.SOL` | Solana | `<SOLANA_TREASURY_ADDRESS>` | $APN + Solana DeFi |
| `crypto.TON` | TON | `<TON_TREASURY_ADDRESS>` | TON ecosystem |
| `crypto.BTC` | Bitcoin | `<BTC_TREASURY_ADDRESS>` | Cold storage (optional) |
| `crypto.MATIC` | Polygon | `0x9505578Bd5b32468E3cEa632664F7b8d2e46128c` | Same EVM treasury |

> Replace `<...>` placeholders with air-gapped treasury addresses before MAINNET cutover.

---

## Website / Frontend Records

### Option A: Unstoppable Domains Website (IPFS)

In UD Dashboard → Website:

| Setting | Value |
|---------|-------|
| Template | IPFS / Custom |
| IPFS Hash | `<VERCEL_IPFS_HASH>` or redirect |
| Redirect | `https://v2-0-bay.vercel.app` (interim) |

### Option B: Cloudflare as DNS Resolver (Recommended)

Point Unstoppable Domains nameservers to Cloudflare:

1. **UD Dashboard** → Domain → **Nameservers** → Custom
2. Set Cloudflare nameservers (from Cloudflare zone setup):
   - `ada.ns.cloudflare.com`
   - `bob.ns.cloudflare.com`

Then in **Cloudflare DNS** for `yieldswarm.crypto`:

| Type | Name | Content | Proxy | TTL |
|------|------|---------|-------|-----|
| CNAME | `@` | `cname.vercel-dns.com` | Proxied | Auto |
| CNAME | `www` | `cname.vercel-dns.com` | Proxied | Auto |
| CNAME | `dashboard` | `cname.vercel-dns.com` | Proxied | Auto |
| CNAME | `app` | `cname.vercel-dns.com` | Proxied | Auto |
| CNAME | `council` | `cname.vercel-dns.com` | Proxied | Auto |
| CNAME | `api` | `<AKASH_INGRESS_URI>` | DNS only | 300 |
| CNAME | `api-testnet` | `<AKASH_TESTNET_URI>` | DNS only | 300 |
| A | `vault` | `<VAULT_SERVER_IP>` | DNS only | 300 |
| TXT | `@` | `v=spf1 include:_spf.google.com ~all` | — | Auto |
| TXT | `_dmarc` | `v=DMARC1; p=none; rua=mailto:cbrown03777@gmail.com` | — | Auto |

### Akash Ingress URI

After deploy, get the provider URI:

```bash
akash provider lease-status --dseq <DSEQ> -o json | jq -r '.services[] | select(.name=="api-gateway") | .uris[0]'
# Example: https://provider.hurricane.akash.pub:8443/<lease-id>
```

Set `api.yieldswarm.crypto` CNAME to that URI host, or use Cloudflare Workers reverse proxy.

---

## API Subdomain Wiring

### Cloudflare Worker (optional reverse proxy)

```javascript
// workers/api-proxy.js
export default {
  async fetch(request) {
    const AKASH_API = 'https://provider.hurricane.akash.pub:8443/<lease-id>';
    const url = new URL(request.url);
    url.hostname = new URL(AKASH_API).hostname;
    url.pathname = new URL(AKASH_API).pathname + url.pathname;
    return fetch(new Request(url, request));
  }
};
```

Route: `api.yieldswarm.crypto/*` → Worker → Akash lease.

---

## Webhook Endpoints

| Provider | Webhook URL | Notes |
|----------|-------------|-------|
| Square | `https://api.yieldswarm.crypto/api/v1/payments/webhooks/square` | Set in Square Developer Dashboard |
| Wise | `https://api.yieldswarm.crypto/api/v1/payments/webhooks/wise` | Business API webhooks |
| Vercel | `https://api.yieldswarm.crypto/api/v1/webhooks/vercel` | Deploy notifications |

---

## Per-Environment Subdomains

| Environment | API | Dashboard | Vault |
|-------------|-----|-----------|-------|
| development | `localhost:3000` | `localhost:5173` | `localhost:8200` |
| testnet | `api-testnet.yieldswarm.crypto` | `dashboard-testnet.yieldswarm.crypto` | `vault-testnet.internal` |
| devnets | `shard-N.devnets.yieldswarm.crypto` | — | shared |
| production | `api.yieldswarm.crypto` | `dashboard.yieldswarm.crypto` | `vault.yieldswarm.crypto` |
| MAINNET | `api.yieldswarm.crypto` | `dashboard.yieldswarm.crypto` | `vault.yieldswarm.crypto` |

---

## Step-by-Step: Unstoppable Domains Dashboard

1. Log in at [unstoppabledomains.com](https://unstoppabledomains.com)
2. **My Domains** → `yieldswarm.crypto`
3. **Crypto Addresses** tab:
   - Add ETH → `0x9505578Bd5b32468E3cEa632664F7b8d2e46128c`
   - Add SOL, TON per treasury table above
4. **Website** tab:
   - Set redirect to Vercel or IPFS hash
5. **Nameservers** tab:
   - Switch to Cloudflare custom nameservers (if using Cloudflare DNS)
6. **Email** (optional):
   - Forward `cbrown03777@gmail.com` via UD email or Cloudflare Email Routing

---

## Step-by-Step: Cloudflare Setup

```bash
# 1. Add site in Cloudflare dashboard
# 2. Import DNS records from table above
# 3. SSL/TLS → Full (strict)
# 4. Enable HSTS for production

# API origin certificate (if terminating TLS at Cloudflare)
# Generate origin cert for api.yieldswarm.crypto → install on Akash ingress
```

---

## Verification

```bash
# DNS resolution
dig api.yieldswarm.crypto
dig dashboard.yieldswarm.crypto

# HTTPS
curl -I https://api.yieldswarm.crypto/health
curl -I https://dashboard.yieldswarm.crypto

# Crypto address resolution (UD)
# Visit: https://resolve.unstoppabledomains.com/resolve/yieldswarm.crypto/ETH

# Webhook reachability
curl -X POST https://api.yieldswarm.crypto/api/v1/payments/webhooks/square \
  -H "Content-Type: application/json" \
  -d '{"type":"test"}'
# Expect 401 (signature missing) — confirms route is live
```

---

## Security Notes

- Keep `vault.yieldswarm.crypto` DNS-only (no Cloudflare proxy) or restrict to VPN IP allowlist
- Rotate UD API key (`UD_API_KEY` in Vault, not `.env`)
- Enable Cloudflare WAF rules on `api.*` for rate limiting
- MAINNET: require mTLS between Cloudflare Worker and Akash origin
