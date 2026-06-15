# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production wiring plan for pointing Unstoppable Domains at YieldSwarm / Kairo
infrastructure (Vercel frontend, Akash endpoints, future API domains) and for
publishing treasury wallet records.

> **Scope:** This is a runbook. DNS and UD records are set in the Unstoppable
> Domains dashboard and your DNS provider — credentials stay in Vault / Vercel,
> not in this repo.

---

## 0. Prerequisites

| Item | Source | Current value |
|------|--------|---------------|
| Vercel frontend | Vercel dashboard | `https://v2-0-bay.vercel.app` |
| Vercel project | README | `vercel.com/support-6930s-projects/v2-0` |
| Akash SDL | `deploy/deploy-swarm-monolith.yaml` | 3× RTX 3090 workers |
| Akash lease manager | `akash/lease-manager.py` | Auto-failover + telemetry |
| Vault secrets | `SECRETS.md` | `vault.yieldswarm.internal:8200` |
| Treasury wallets | Your multisig | Fill in Section 4 below |

---

## 1. Domain registry (17 domains)

The council status page reports **17 domains wired**. Register each domain in
this table with the exact records from your UD dashboard. Primary names are
recommended; fill `YOUR_DOMAIN_N` from your UD account.

### 1a. Primary product domains

| # | Domain (UD) | Role | Website / apex | `app.` | `api.` | `dashboard.` |
|---|-------------|------|----------------|--------|--------|--------------|
| 1 | `yieldswarm.crypto` | Main brand | Vercel | Vercel | Akash proxy | Vercel/Akash |
| 2 | `yieldswarm.x` | Alt TLD / mobile | Vercel | Vercel | Akash proxy | Vercel |
| 3 | `kairo.x` | Kairo identity app | Vercel (future `/kairo`) | Vercel | Akash proxy | Akash |
| 4 | `kairo.crypto` | Kairo alt TLD | Vercel | Vercel | Akash proxy | Akash |
| 5 | `helixchain.crypto` | Helix Chain genesis | Vercel | — | RPC node | Grafana |
| 6 | `agentswarm.crypto` | AgentSwarm OS | Vercel | Vercel | Akash | Akash |

### 1b. Treasury & payments domains

| # | Domain (UD) | Role | Crypto records |
|---|-------------|------|----------------|
| 7 | `yieldswarm.wallet` | Treasury resolution | ETH, BTC, SOL, MATIC |
| 8 | `apn.crypto` | `$APN` token ops | SOL (treasury wallet, **not** mint) |
| 9 | `yslr.crypto` | YSLR receipts | ETH, SOL |

### 1c. DePIN & marketplace domains

| # | Domain (UD) | Role | Website |
|---|-------------|------|---------|
| 10 | `depin.crypto` | DePIN hardware marketplace | Vercel `/marketplace` |
| 11 | `z15.crypto` | Antminer Z15 sales | Vercel `/sales` |
| 12 | `openclaw.crypto` | OpenClaw admin | Akash dashboard |
| 13 | `odysseus.crypto` | Odysseus agent workspace | Akash |

### 1d. Council & arena domains

| # | Domain (UD) | Role | Website |
|---|-------------|------|---------|
| 14 | `council.crypto` | DAO governance | Vercel `/council/status` |
| 15 | `arena.crypto` | Agents arena leaderboard | Akash telemetry |
| 16 | `kimiclaw.crypto` | Consensus council | Akash |

### 1e. Reserve

| # | Domain (UD) | Role | Notes |
|---|-------------|------|-------|
| 17 | `YOUR_DOMAIN_17` | Reserve / staging | Point at `v2-0-bay.vercel.app` until assigned |

> Replace placeholder names with your actual UD portfolio. If you own different
> TLDs (`.nft`, `.blockchain`, `.888`), add rows — the record types are identical.

---

## 2. Exact records to set tonight (primary: `yieldswarm.crypto`)

Do these in **Unstoppable Domains → My Domains → yieldswarm.crypto → Manage**.

### Step 1 — Website (apex)

| UD field | Value |
|----------|-------|
| **Website** | `https://v2-0-bay.vercel.app` |

Redirects apex traffic to the live Vercel deployment until custom domains are
verified on Vercel.

### Step 2 — Crypto / treasury records

| Record key | Value | Notes |
|------------|-------|-------|
| `crypto.ETH.address` | `0xYOUR_ETH_TREASURY_MULTISIG` | Gnosis Safe recommended |
| `crypto.BTC.address` | `bc1YOUR_BTC_TREASURY` | Hardware wallet or multisig |
| `crypto.SOL.address` | `YOUR_SOL_TREASURY_PUBKEY` | Squads multisig recommended |
| `crypto.MATIC.address` | `0xYOUR_POLYGON_TREASURY` | Same as ETH if unified |
| `crypto.USDC.address` | `0xYOUR_USDC_RECEIVING` | Optional |

`$APN` mint (public, **do not** use as treasury):
`8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump`

### Step 3 — DNS records (traditional path, recommended)

In UD → **DNS Records** (or delegate to Cloudflare — see Section 3):

| Type | Host | Target | TTL |
|------|------|--------|-----|
| CNAME | `app` | `cname.vercel-dns.com` | 300 |
| CNAME | `www` | `cname.vercel-dns.com` | 300 |
| CNAME | `api` | `api-proxy.yieldswarm.internal` | 300 |
| CNAME | `dashboard` | `cname.vercel-dns.com` | 300 |

After adding `app.yieldswarm.crypto` in **Vercel → Project → Settings → Domains**,
Vercel may show a different CNAME — use Vercel's value, not the generic one above.

### Step 4 — Vercel custom domains

In Vercel project `v2-0`:

```
app.yieldswarm.crypto
www.yieldswarm.crypto
dashboard.yieldswarm.crypto
```

Vercel auto-provisions TLS once DNS propagates (typically 5–30 minutes).

### Step 5 — Repeat for `kairo.x`

| UD field | Value |
|----------|-------|
| **Website** | `https://v2-0-bay.vercel.app/kairo` (or dedicated Kairo Vercel project) |
| `app.kairo.x` CNAME | `cname.vercel-dns.com` |
| `api.kairo.x` CNAME | Akash stable proxy host (see Section 5) |
| `crypto.ETH.address` | Same treasury multisig as yieldswarm |

---

## 3. Cloudflare delegation (recommended)

For browser-wide resolution of `.crypto` / `.x` names:

1. **Cloudflare** → Add site → enter `yieldswarm.crypto` (or use UD's Web2 bridge).
2. Copy Cloudflare nameservers (e.g. `ada.ns.cloudflare.com`, `bob.ns.cloudflare.com`).
3. **UD dashboard** → domain → **Nameservers** → paste Cloudflare NS values.
4. In Cloudflare DNS, create the CNAME records from Section 2 Step 3.
5. SSL/TLS → **Full (strict)**. Enable proxy (orange cloud) on `app` and `www`.
6. Add `_dnslink` TXT if using IPFS dweb (optional).

Repeat per domain, or use a single Cloudflare account with 17 zones.

---

## 4. Decentralized website path (optional IPFS)

For censorship-resistant static hosting:

1. Build static export: `make build` (or `vercel build --prod`).
2. Pin to IPFS (Pinata / web3.storage / Filecoin — keys in Vault).
3. UD → **Website** → paste CID (e.g. `bafybei...`).
4. Verify: `https://<CID>.ipfs.dweb.link` and Brave / UD extension.

Use **either** Path A (Vercel DNS) **or** Path B (IPFS) per domain — not both on apex.

---

## 5. Akash endpoint wiring

Once `scripts/akash-deploy.sh` or `make akash-lease` succeeds:

```bash
# Deploy monolith (3× RTX 3090)
export AKASH_KEY_NAME=yieldswarm
export AUTO_SELECT_BID=1
./scripts/akash-deploy.sh deploy/deploy-swarm-monolith.yaml

# Or use the lease manager for auto-failover
cd akash && ./run.sh
```

Capture the provider URI:

```bash
provider-services lease-status \
  --owner "$(provider-services keys show yieldswarm -a)" \
  --node https://rpc.akashnet.net:443
```

Put a **stable reverse proxy** in front (Cloudflare Worker, nginx, or
`api-proxy.yieldswarm.internal`) so `api.<domain>` does not break when leases
move providers. Point all `api.*` CNAMEs at that stable host.

| Service | Akash SDL | Exposed port |
|---------|-----------|--------------|
| Swarm monolith | `deploy/deploy-swarm-monolith.yaml` | 80 → 8080 |
| GPU worker | `akash/worker.sdl.yml` | 80, 9090 |
| Vault runtime | `akash/deploy.yaml` | 8080 |

---

## 6. Subdomain matrix (all 17 domains)

Apply this pattern to every domain in Section 1:

| Subdomain | Target | Record type |
|-----------|--------|-------------|
| `@` (apex) | Vercel URL or IPFS CID | Website |
| `app` | Vercel CNAME | DNS CNAME |
| `api` | Akash stable proxy | DNS CNAME |
| `dashboard` | Vercel or Akash Grafana | DNS CNAME |
| `status` | `council/status.html` path | CNAME → Vercel |
| `arena` | Akash telemetry (`akash/telemetry/`) | CNAME → Akash |

---

## 7. Programmatic updates (UD API)

Store `UD_API_KEY` in HashiCorp Vault (`yieldswarm/integrations/ud`), inject at
runtime — never commit.

```bash
# Issue wrapped secret_id, then:
export UD_API_KEY="$(vault kv get -field=api_key yieldswarm/integrations/ud)"

curl -s "https://api.unstoppabledomains.com/resolve/domains/yieldswarm.crypto" \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

Docs: https://docs.unstoppabledomains.com/

---

## 8. Security

1. **Rotate** any `UD_API_KEY` previously committed to `.env.example` — revoke in
   UD dashboard, re-seed via `./vault/scripts/seed-secrets.sh`.
2. Verify crypto records character-by-character before signing on-chain.
3. Use multisig treasuries (Gnosis Safe / Squads), not EOAs.
4. Audit UD record changes if the old API key was exposed.

---

## 9. Verification checklist

- [ ] UD Website record → `v2-0-bay.vercel.app` (or IPFS CID)
- [ ] `app.yieldswarm.crypto` resolves and shows valid HTTPS
- [ ] `api.yieldswarm.crypto` → Akash worker health (`/healthz` returns 200)
- [ ] Crypto records verified; small test transfer on each chain
- [ ] All 17 domains logged in Section 1 table with actual names
- [ ] Cloudflare proxy + Full (strict) TLS enabled
- [ ] `UD_API_KEY` only in Vault; old key revoked
- [ ] Vercel custom domains show "Valid Configuration"

---

## 10. Quick commands

```bash
# Check DNS propagation
dig app.yieldswarm.crypto CNAME +short
dig api.yieldswarm.crypto CNAME +short

# Check Vercel domain status
vercel domains ls --token "$VERCEL_API_TOKEN"

# Check Akash lease health
curl -sf "https://api.yieldswarm.crypto/healthz" || echo "API not wired yet"

# Full deploy (after domains + secrets ready)
make preflight && make deploy
```
