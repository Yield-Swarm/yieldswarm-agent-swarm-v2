# DOMAINS.md — Unstoppable Domains + Infrastructure Wiring

Production wiring plan for pointing Unstoppable Domains at YieldSwarm / Kairo
infrastructure (Vercel frontend, Akash endpoints, future API domains) and for
publishing treasury wallet records.

> **Scope note:** This document is a runbook. It does **not** execute any
> changes — Unstoppable Domains records and DNS are set in the UD dashboard /
> your DNS provider, both of which require credentials this repo does not (and
> should not) contain. Follow the steps below to apply the configuration.

---

## 0. Prerequisites

Before wiring anything, gather:

| Item | Where it comes from | Notes |
|------|--------------------|-------|
| Domain name(s) | Unstoppable Domains dashboard | e.g. `yieldswarm.crypto`, `kairo.x` |
| UD account access | https://unstoppabledomains.com → My Domains | Wallet or email login |
| Vercel deployment URL | Vercel dashboard | Current: `v2-0-bay.vercel.app` (see `README.md`) |
| Akash endpoint | After `akash` lease deploys | `*.provider.<region>.akash.network` host + port |
| Treasury wallet addresses | Your multisig / treasury | ETH, BTC, SOL, etc. |
| UD API key (optional) | UD dashboard → Profile → API | Only needed for programmatic record updates |

> The repo currently has **no** Akash SDL, Terraform, or `vercel.json`. Until
> those exist, point the Website record at the Vercel URL and revisit the Akash
> rows once a lease is live.

---

## 1. Domain → target map

Decide what each name/subdomain resolves to. Recommended layout:

| Record / subdomain | Target | Record type | Purpose |
|--------------------|--------|-------------|---------|
| `@` (apex Website) | `https://v2-0-bay.vercel.app` | Website / redirect URL | Main app |
| `app.<domain>` | Vercel deployment | CNAME (via traditional DNS) | App frontend |
| `api.<domain>` | Akash endpoint or API host | CNAME / A | Backend API |
| `dashboard.<domain>` | OpenClaw admin (Vercel/Akash) | CNAME | Admin dashboard |
| `dweb` / IPFS | IPFS CID (optional) | `dweb.ipfs.hash` | Decentralized hosting |
| `crypto.ETH.address` | Treasury ETH/EVM address | Crypto record | Wallet resolution |
| `crypto.BTC.address` | Treasury BTC address | Crypto record | Wallet resolution |
| `crypto.SOL.address` | Treasury / `$APN` ops wallet | Crypto record | Wallet resolution |

`$APN` token mint (public, from `.env.example`):
`8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump` — this is a token mint, **not** a
wallet, so do not put it in `crypto.SOL.address`. Use your actual treasury
wallet for crypto records.

---

## 2. Two resolution paths (pick one per domain)

Unstoppable Domains supports two ways to serve a website. Choose based on
whether you want classic HTTPS hosting (Vercel/Akash) or decentralized hosting.

### Path A — Traditional DNS (recommended for Vercel/Akash)

Use this when the site is hosted on Vercel or Akash. UD lets you set standard
DNS records (or delegate via Cloudflare nameservers).

1. UD dashboard → select domain → **Manage** → **DNS / Records**.
2. Add records:
   - `A` / `CNAME` for `app` → your Vercel target.
   - `CNAME` for `api` → Akash endpoint host.
3. In **Vercel** → Project → Settings → Domains → add `app.<domain>`; Vercel
   shows the exact `CNAME` / `A` value to enter back in UD.
4. (Optional, recommended) Delegate the whole domain to **Cloudflare**:
   - In UD: set custom nameservers to the two Cloudflare NS values.
   - In Cloudflare: create the zone, add the `A`/`CNAME` records above, enable
     proxy + "Full (strict)" TLS. This gives you CDN, WAF, and easy cert mgmt.

> Browser support: traditional DNS resolution for `.crypto`/`.x` etc. requires a
> resolver-aware path (Cloudflare's `_dnslink` / UD's web2 bridge) for ordinary
> browsers. Pure UD names resolve natively only in UD-aware browsers/extensions.

### Path B — Decentralized website (IPFS / dweb)

Use this for a censorship-resistant static frontend.

1. Build the static site and upload to IPFS (Pinata, web3.storage, or Filecoin —
   see `FILECOIN_STORAGE_KEY` / `IPFS_GATEWAY` in `.env.example`).
2. Copy the resulting CID (e.g. `Qm...` or `bafy...`).
3. UD dashboard → domain → **Website** → paste the IPFS hash.
4. Verify via the gateway: `https://<CID>.ipfs.dweb.link` and the UD name in a
   UD-aware browser (Brave, or the UD extension).

---

## 3. Crypto (treasury) records

For each treasury chain, in UD dashboard → domain → **Crypto / Addresses**:

1. Add the address for each ticker you support: `ETH`, `BTC`, `SOL`, `MATIC`,
   `USDC`, etc.
2. **Always verify** the first few + last few characters after pasting — wrong
   crypto records silently misroute funds.
3. Prefer a **multisig** (e.g. Gnosis Safe on EVM, Squads on Solana) over an EOA
   for treasury records.
4. Sign the on-chain UD transaction (gas required) to persist records.

---

## 4. Programmatic updates (optional)

If you manage many domains/records, use the UD API instead of the dashboard.

- Get a key: UD dashboard → Profile → **API Keys**.
- Store it in your secret manager (e.g. HashiCorp Vault), inject at runtime as
  `UD_API_KEY`. **Never** commit it (see Security section).
- Reference: https://docs.unstoppabledomains.com/

Example shape (verify against current UD API docs before use):

```bash
# UD_API_KEY supplied from your secret manager, NOT from the repo
curl -s https://api.unstoppabledomains.com/resolve/domains/<yourdomain> \
  -H "Authorization: Bearer ${UD_API_KEY}"
```

---

## 5. Akash endpoint wiring (do this once a lease is live)

The repo references Akash but has no deploy manifest yet. Once you have a live
Akash lease:

1. Note the provider host + exposed port from `akash lease-status` /
   `provider-services lease-status`.
2. Put a stable reverse proxy in front (Cloudflare or an nginx box) so the
   public name does not change when the lease re-deploys to a new provider.
3. Point `api.<domain>` (Path A) at that stable host.
4. Document the chosen provider/region here once selected.

---

## 6. Security & secret rotation (IMPORTANT)

A live-looking `UD_API_KEY` was previously committed to `.env.example` in this
repo's history. Treat it as **compromised**:

1. **Rotate it now:** UD dashboard → Profile → API Keys → revoke the old key,
   generate a new one.
2. Store the new key only in a secret manager (Vault / Vercel env vars / GitHub
   Actions secrets). The repo template now uses a placeholder.
3. (Optional) Scrub the key from git history with `git filter-repo` or BFG, then
   force-push — coordinate this with the team since it rewrites history.
4. Audit for any unauthorized record changes made while the key was exposed.

---

## 7. Verification checklist

- [ ] UD `Website` record resolves to the intended Vercel/IPFS target.
- [ ] `app.` / `api.` / `dashboard.` subdomains resolve (dig / browser test).
- [ ] Crypto records verified character-by-character; small test transfer ok.
- [ ] HTTPS valid (Cloudflare/Vercel cert issued, no mixed content).
- [ ] Old UD API key revoked; new key only in secret manager.
- [ ] This file updated with the actual domain names and chosen targets.
