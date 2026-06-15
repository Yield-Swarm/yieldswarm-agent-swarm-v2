# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production wiring plan for pointing Unstoppable Domains at YieldSwarm / Kairo
infrastructure (Vercel frontend, Akash endpoints, API domains) and for
publishing treasury wallet records.

> **Scope note:** This document is a runbook. It does **not** execute any
> changes — Unstoppable Domains records and DNS are set in the UD dashboard /
> your DNS provider. Follow the steps below to apply the configuration.

---

## 0. Prerequisites

| Item | Where it comes from | Notes |
|------|--------------------|-------|
| Domain name(s) | Unstoppable Domains dashboard | e.g. `yieldswarm.crypto`, `kairo.x` |
| UD account access | https://unstoppabledomains.com → My Domains | Wallet or email login |
| Vercel deployment URL | Vercel dashboard | Current: `v2-0-bay.vercel.app` (see `README.md`) |
| Akash endpoint | After `./scripts/akash-deploy.sh` | `*.provider.<region>.akash.network` |
| Backend API | After `./deploy.sh` or Codespace deploy | Integration server on `:8080` |
| Kairo API | After `python -m kairo.api.server` | Driver dashboard on `:3001` |
| Treasury wallet addresses | Your multisig / treasury | ETH, SOL, TON, etc. |
| UD API key (optional) | UD dashboard → Profile → API | Store in Vault as `UD_API_KEY` |

---

## 1. Domain → target map

Recommended layout for YieldSwarm + Kairo:

| Record / subdomain | Target | Record type | Purpose |
|--------------------|--------|-------------|---------|
| `@` (apex Website) | `https://v2-0-bay.vercel.app` | Website / redirect URL | Main marketing site |
| `app.` | Vercel deployment | CNAME | YieldSwarm + Kairo app frontend |
| `api.` | Akash worker or stable proxy | CNAME / A | Backend integration server (`/api/*`) |
| `kairo.` | Kairo API host | CNAME | Driver app + contribution dashboard |
| `dashboard.` | OpenClaw admin (Vercel/Akash) | CNAME | Admin dashboard |
| `odysseus.` | Odysseus workspace (private) | CNAME (Tailscale/CF Access) | Agent orchestration UI |
| `vault.` | HashiCorp Vault cluster | A (private) | Secret management |
| `dweb` / IPFS | IPFS CID (optional) | `dweb.ipfs.hash` | Decentralized static hosting |
| `crypto.ETH.address` | Treasury EVM address | Crypto record | `TREASURY_EVM_ADDRESS` |
| `crypto.SOL.address` | Treasury Solana address | Crypto record | `TREASURY_SOLANA_ADDRESS` |
| `crypto.TON.address` | Treasury TON address | Crypto record | `TREASURY_TON_ADDRESS` |

`$APN` token mint (public): `8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump` — this is a
token mint, **not** a wallet. Do not put it in `crypto.SOL.address`.

---

## 2. Exact DNS records (Cloudflare resolver path)

If using Cloudflare as resolver (recommended):

### yieldswarm.crypto (example)

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| CNAME | `app` | `cname.vercel-dns.com` | Yes |
| CNAME | `api` | `<akash-proxy-host>` | Yes |
| CNAME | `kairo` | `<kairo-api-host>` | Yes |
| CNAME | `dashboard` | `cname.vercel-dns.com` | Yes |
| CNAME | `odysseus` | `<tailscale-or-cf-tunnel-host>` | No (private) |
| TXT | `_dnslink` | `dnslink=/ipfs/<CID>` | No (if using IPFS) |

### kairo.x (example — future Kairo app)

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| CNAME | `app` | `cname.vercel-dns.com` | Yes |
| CNAME | `api` | `<kairo-api-host>` | Yes |

### Vercel domain setup

1. Vercel → Project `v2-0` → Settings → Domains
2. Add: `app.yieldswarm.crypto`, `dashboard.yieldswarm.crypto`
3. Copy the CNAME target Vercel provides → enter in UD or Cloudflare

---

## 3. Crypto (treasury) records

In UD dashboard → domain → **Crypto / Addresses**:

| Ticker | Env var | Example placeholder |
|--------|---------|---------------------|
| ETH | `TREASURY_EVM_ADDRESS` | `0x9505578Bd5b32468E3cEa632664F7b8d2e46128c` |
| SOL | `TREASURY_SOLANA_ADDRESS` | `<your-solana-treasury>` |
| TON | `TREASURY_TON_ADDRESS` | `<your-ton-treasury>` |
| MATIC | (same as EVM if shared) | — |
| USDC | (same as EVM if shared) | — |

**Always verify** the first and last 6 characters after pasting. Prefer multisig
(Gnosis Safe on EVM, Squads on Solana) over EOAs for treasury records.

---

## 4. Akash endpoint wiring

After deploying with `./scripts/akash-deploy.sh` or `./scripts/codespace-deploy.sh`:

```bash
# Get lease URI
provider-services lease-status --dseq <DSEQ> --from <KEY>

# Example output host: provider.us-west-2.akash.network:32145
```

1. Put a stable reverse proxy in front (Cloudflare Tunnel or nginx) so the public
   name does not change when leases re-deploy.
2. Point `api.yieldswarm.crypto` CNAME at the stable proxy host.
3. Set `AKASH_OLLAMA_BASE_URL` in Vault to the internal Ollama worker URL for
   Odysseus model routing.

---

## 5. Programmatic updates (optional)

Store `UD_API_KEY` in Vault at `kv/data/yieldswarm/integrations/unstoppable-domains`.

```bash
# Load from Vault
source scripts/lib/vault-env.sh
vault_export_env kv/data/yieldswarm/integrations/unstoppable-domains

# Resolve a domain
curl -s "https://api.unstoppabledomains.com/resolve/domains/yieldswarm.crypto" \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

Reference: https://docs.unstoppabledomains.com/

---

## 6. Security

1. **Never commit** `UD_API_KEY` — use Vault or Vercel env vars.
2. Rotate any key that was ever committed to git history.
3. Keep `vault.` and `odysseus.` behind Tailscale or Cloudflare Access.
4. Do not expose unauthenticated Ollama endpoints to the public internet.

---

## 7. Verification checklist

- [ ] UD `Website` record resolves to Vercel/IPFS target
- [ ] `app.` / `api.` / `kairo.` / `dashboard.` subdomains resolve (dig + browser)
- [ ] Crypto records verified character-by-character; small test transfer ok
- [ ] HTTPS valid (Cloudflare/Vercel cert, no mixed content)
- [ ] `UD_API_KEY` only in Vault; old keys revoked
- [ ] Akash proxy stable across lease re-deploys
- [ ] Kairo dashboard reachable at `kairo.<domain>/api/kairo/dashboard`
