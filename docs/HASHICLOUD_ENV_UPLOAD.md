# HashiCloud / HCP Vault — Environment Upload

Upload secrets to **HashiCorp Cloud Platform (HCP) Vault** using the repo’s flat env files and `vault/scripts/seed-secrets.sh`.

## Files

| File | Committed? | Purpose |
|------|------------|---------|
| `example.env` | Yes | Placeholder-only template for HashiCloud / team handoff |
| `.env.example` | Yes | Same catalog as `example.env` (canonical name in docs) |
| `.env` | **No** (gitignored) | Your filled copy — never push to GitHub |

Regenerate templates after catalog changes:

```bash
python3 scripts/build-hashicloud-env.py
```

## Quick start

```bash
# 1. Copy template
cp example.env .env

# 2. Edit .env — set VAULT_ADDR, VAULT_TOKEN, API keys, Akash mnemonic, etc.

# 3. Load into shell (avoids leaking values on CLI)
set -a
source .env
set +a

# 4. Seed KV v2 mount (default: yieldswarm)
./vault/scripts/seed-secrets.sh
```

Prerequisites:

- `vault` CLI installed and logged into HCP (`vault login` or `VAULT_TOKEN`)
- `VAULT_ADDR` points at your HCP cluster (e.g. `https://xxx.hashicorp.cloud:8200`)
- Admin token in `VAULT_TOKEN` on the **seed host only** — not in Akash SDL or Vercel

## HCP Vault console upload

If you prefer the UI instead of the seed script:

1. Open your HCP Vault cluster → **Secrets** → enable KV secrets engine mount `yieldswarm` (v2) if missing.
2. Create paths from `docs/VAULT_SECRET_STRUCTURE.md` (e.g. `yieldswarm/runtime/llm`, `yieldswarm/providers/runpod`).
3. Map each JSON key from the structure doc to the matching env var in `example.env`.

The seed script is still recommended — it stays in sync with `vault/scripts/seed-secrets.sh` and avoids manual path typos.

## Critical variables (fill first)

| Area | Variables |
|------|-----------|
| Vault operator | `VAULT_ADDR`, `VAULT_TOKEN`, `KV_MOUNT` |
| Akash deploy | `AKASH_WALLET_MNEMONIC`, `AKASH_KEY_NAME`, `AKASH_OWNER_ADDRESS`, `AKASH_PROVIDER` |
| AppRole (runtime) | `VAULT_ROLE_ID`, `VAULT_WRAPPED_SECRET_ID` (from `vault/scripts/issue-secret-id.sh`) |
| Database | `DATABASE_URL`, `NEON_PROJECT_ID` |
| LLM | `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GROK_API_KEY`, `YIELDSWARM_ROUTER_API_KEY` |
| Payments | `STRIPE_SECRET_KEY`, `SQUARE_ACCESS_TOKEN`, `WISE_API_TOKEN` |
| Mining | `MONERO_WALLET_ADDRESS`, `KASPA_WALLET_ADDRESS`, `RUNPOD_API_KEY` |

Full catalog: `docs/ENV_VARS.md`.

## Security

- **Never** commit `.env` with real values.
- **Rotate** any secret that appeared in Polsia/Gemini chat logs or support tickets.
- Use **AppRole + wrapped SecretID** for Akash workloads; keep `VAULT_TOKEN` on deploy/seed hosts only.
- Public payout addresses in docs are placeholders in `example.env`; set your real addresses only in `.env` / Vault.

## Related docs

- `docs/VAULT_SECRET_STRUCTURE.md` — KV path tree
- `docs/VAULT_ENV_INJECTION.md` — runtime injection into Akash SDL
- `deploy/akash.env.example` — Akash-only subset (also merged into `example.env`)
- `SECRETS.md` — high-level secrets policy
