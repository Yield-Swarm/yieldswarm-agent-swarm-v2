# Vault + Akash Deployment Guide

HashiCorp Vault is the secret source of truth for all Akash workloads.
This guide answers the common bootstrap questions and gives copy-paste deploy paths.

---

## Recommended deploy order (fastest path to revenue)

| Priority | SDL | Script | GPU | Vault role |
|----------|-----|--------|-----|------------|
| **1** | `deploy/akash-bittensor-miner.sdl.yml` | `scripts/deploy-bittensor.sh` | RTX 3090 | `bittensor-runtime` |
| **2** | `deploy/akash-backend.sdl.yml` | `scripts/deploy-backend-akash.sh` | CPU only | `integration-backend` |
| **3** | `deploy/akash-odysseus.sdl.yml` | `scripts/deploy-odysseus-vault-akash.sh` | 2× GPU | `odysseus-runtime` |
| 4 | `deploy/deploy-swarm-monolith.yaml` | `scripts/deploy-to-akash.sh` | 3× RTX 3090 | `akash-runtime` |

**Fastest path:** seed Vault → deploy **one Bittensor miner** → deploy **light backend** → point Arena at lease URIs.

---

## Using your $500 HashiCorp credit

| Use | Est. monthly | Notes |
|-----|--------------|-------|
| Terraform Cloud (Helixchainprod workspace) | $0–50 | Remote state + team runs |
| Self-hosted Vault (small VM or Akash) | $20–40 | Required for production secrets |
| HCP Vault (optional) | $30+ | Skip unless you want managed HA |
| Boundary / Waypoint | — | Not needed yet |

Keep ~$300 buffer for 6+ months of Vault + TFC while revenue ramps.

---

## Step 1 — Bootstrap Vault (one time)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<admin-token>

# Full setup (policies, AppRoles, KV mount)
./vault/setup/bootstrap.sh    # or vault/scripts/bootstrap.sh on older layouts

# Load policies (includes integration-backend, bittensor-runtime, odysseus-runtime)
./vault/setup/03-write-policies.sh
./vault/setup/04-enable-auth.sh
```

Key KV paths to seed:

| Path | Purpose |
|------|---------|
| `yieldswarm/runtime/bittensor` | Miner wallet, netuid, Ollama model |
| `yieldswarm/runtime/akash` | `owner_address`, deploy wallet metadata |
| `yieldswarm/runtime/backend` | Emission router, treasury, splits |
| `yieldswarm/runtime/odysseus` | API keys, router key, OpenRouter/Fireworks |
| `yieldswarm/runtime/payments` | Stripe/Square/Wise (Vercel, not Akash) |
| `yieldswarm/rpc/solana` | `url`, `helius_api_key` |

```bash
# Export secrets from your local .env (never commit), then:
./vault/scripts/seed-secrets.sh
```

Manual example:

```bash
vault kv put yieldswarm/runtime/akash owner_address="akash1..."
vault kv put yieldswarm/runtime/backend \
  emission_router_address="..." \
  treasury_address="..." \
  apn_mint="8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump"
vault kv put yieldswarm/runtime/bittensor \
  netuid="1" network="finney" wallet_name="miner" hotkey_name="default"
```

---

## Step 2 — Issue AppRole credentials for Akash

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<admin-or-ci-bootstrap>

# Prints export lines — eval into your shell:
eval "$(./scripts/akash-vault-prepare.sh integration-backend)"
# → VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID
```

Roles:

| Role | SDL |
|------|-----|
| `integration-backend` | `deploy/akash-backend.sdl.yml` |
| `bittensor-runtime` | `deploy/akash-bittensor-miner.sdl.yml` |
| `odysseus-runtime` | `deploy/akash-odysseus.sdl.yml` (render-time) |
| `akash-runtime` | `deploy/deploy-swarm-monolith.yaml` (wrapped SecretID) |

Secret IDs are **single-use** per AppRole config. Re-run `akash-vault-prepare.sh` before each new deployment.

---

## Step 3 — Deploy integration backend (your SDL)

```bash
# Build Vault-enabled image (first time)
docker build -f backend/Dockerfile.akash -t ghcr.io/yieldswarm/yieldswarm-backend:latest .
docker push ghcr.io/yieldswarm/yieldswarm-backend:latest

# Wallet + Vault
export AKASH_OWNER_ADDRESS=akash1...   # optional if set in Vault runtime/akash
eval "$(./scripts/akash-vault-prepare.sh integration-backend)"

chmod +x scripts/deploy-backend-akash.sh
./scripts/deploy-backend-akash.sh
```

SDL: [`deploy/akash-backend.sdl.yml`](../deploy/akash-backend.sdl.yml)

- **Port 8080** → Arena `/api/*`, sovereign state, Akash telemetry
- **~1500 uakt** bid target (~$1.50–2.50/day depending on provider)
- Secrets loaded at container start via `scripts/vault-export-env.py`

Health check: `curl https://<lease-uri>/api/health`

---

## Step 4 — Deploy Bittensor miner (revenue + telemetry)

See [`BITTENSOR.md`](../BITTENSOR.md).

```bash
export BT_NETUID=1
eval "$(./scripts/akash-vault-prepare.sh bittensor-runtime)"
./scripts/deploy-bittensor.sh
```

Ports: **8080** telemetry (Arena), **8091** axon, **11434** Ollama.

---

## Step 5 — Deploy Odysseus with Vault (render-time secrets)

Odysseus images do not yet embed a Vault Agent sidecar. Secrets are pulled **at deploy time** and substituted into the SDL via `envsubst`:

```bash
eval "$(./scripts/akash-vault-prepare.sh odysseus-runtime)"
./scripts/deploy-odysseus-vault-akash.sh
```

This exports `YIELDSWARM_ROUTER_API_KEY`, `OPENROUTER_API_KEY`, `ODYSSEUS_API_KEY`, etc. from Vault without writing them to git.

---

## Vault injection patterns in this repo

| Pattern | Used by | How |
|---------|---------|-----|
| **vault-export-env.py** | Backend, Bittensor | AppRole login at boot → `source /run/secrets/app.env` |
| **Vault Agent sidecar** | `akash/Dockerfile` monolith worker | `entrypoint.sh` unwraps wrapped SecretID |
| **SDL render-time** | Odysseus stack | Export Vault → envsubst before `deployment create` |

---

## Terraform Cloud (Helixchainprod)

```bash
cd terraform   # or deploy/terraform
terraform login
terraform init
terraform plan
terraform apply
```

Terraform reads cloud/RPC secrets via `data "vault_kv_secret_v2"` — never from `.env` in CI.

---

## Answers to your three questions

1. **Running Vault instance or deploy on Akash?**  
   If not already running: deploy Vault on a **small Hetzner/DO VM** ($5–10/mo) or use **HCP Vault** with your credit. Akash-hosted Vault is possible but adds complexity — use it as a secondary node later.

2. **Which SDL first?**  
   **A. Bittensor miner** (revenue + telemetry) → then **C. light backend** → then **B. Odysseus** when GPU budget allows.

3. **Vault Agent sidecar now?**  
   **Backend + Bittensor:** yes (via `vault-export-env.py` in entrypoint).  
   **Odysseus:** render-time Vault for now; full sidecar in a follow-up image build.  
   **Monolith worker:** already has Vault Agent in `akash/Dockerfile`.

---

## Stripe / Vercel (not on Akash)

Payment secrets live in `yieldswarm/runtime/payments` and deploy to **Vercel**, not Akash SDLs. Webhook: `/api/webhooks/stripe`.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `no secrets rendered` | Check `VAULT_ROLE_ID` + `VAULT_SECRET_ID`; re-issue Secret ID |
| `permission denied` on KV path | Policy mismatch — run `vault/setup/03-write-policies.sh` |
| Backend shows sample Akash fleet | Set `AKASH_OWNER_ADDRESS` in Vault `runtime/akash` |
| Leaderboard HTTP 429 | Set dedicated `SOLANA_RPC_URL` in `rpc/solana` |

---

## Related docs

- [`SECRETS.md`](../SECRETS.md) — operator runbook
- [`docs/ENV_VARS.md`](ENV_VARS.md) — full env catalog
- [`docs/AKASH_DEPLOY.md`](AKASH_DEPLOY.md) — `deploy-to-akash.sh` pipeline
- [`BITTENSOR.md`](../BITTENSOR.md) — miner quick start
