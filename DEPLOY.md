# YieldSwarm Production Deployment Guide

Complete, repeatable deployment for YieldSwarm AgentSwarm OS v2.0 on Akash with HashiCorp Vault secrets, Odysseus orchestration, and Kairo identity pipeline.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| `akash` CLI | ≥0.34 | [docs.akash.network](https://docs.akash.network) |
| `vault` CLI | ≥1.17 | [developer.hashicorp.com/vault](https://developer.hashicorp.com/vault/downloads) |
| `jq` | ≥1.6 | `apt install jq` / `brew install jq` |
| `docker` | ≥24 | For local image builds |
| Node.js | ≥20 | For API services |
| Akash wallet | Funded | ≥5 AKT deposit per deployment |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Akash Lease (RTX 3090)                   │
│  ┌──────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐ │
│  │ Vault    │  │ API      │  │Odysseus │  │ Ollama       │ │
│  │ Agent    │→ │ Gateway  │→ │+ Chroma │→ │ (3090 GPU)   │ │
│  └──────────┘  └──────────┘  └─────────┘  └──────────────┘ │
│       ↓              ↓              ↓                        │
│  ┌──────────┐  ┌──────────┐  ┌─────────┐  ┌──────────────┐ │
│  │ Kairo    │  │ Payments │  │ Health  │  │ Fireworks /  │ │
│  │ Identity │  │ Square+  │  │ Sidecar │  │ OpenRouter   │ │
│  └──────────┘  │ Wise     │  └─────────┘  └──────────────┘ │
│                └──────────┘                                   │
└─────────────────────────────────────────────────────────────┘
         ↑                              ↑
    HashiCorp Vault              Kairo Driver App
    (HCP or self-hosted)         (signed telemetry)
```

---

## Step 1: Codespace / Local Setup

```bash
# Clone and enter repo
git clone https://github.com/<org>/yieldswarm.git
cd yieldswarm
git checkout development   # or production for live deploy

# Copy environment template
cp .env.example .env
# Edit .env — set non-secret config only; secrets go in Vault

# Install dependencies
cd services/api && npm ci && cd ../..

# Make scripts executable
chmod +x scripts/*.sh
```

---

## Step 2: Configure HashiCorp Vault

### 2a. Create secret paths (per environment)

```bash
export VAULT_ADDR="https://vault.yieldswarm.crypto"
vault login

# API secrets
vault kv put secret/yieldswarm/production/api \
  OPENAI_API_KEY="sk-..." \
  ANTHROPIC_API_KEY="sk-..." \
  GROK_API_KEY="..." \
  FIREWORKS_API_KEY="..." \
  OPENROUTER_API_KEY="..." \
  AGENTSWARM_MASTER_KEY="..."

# Akash
vault kv put secret/yieldswarm/production/akash \
  AKASH_KEY_NAME="yieldswarm-deploy" \
  AKASH_MNEMONIC="(stored in TEE only)"

# Payments
vault kv put secret/yieldswarm/production/payments \
  SQUARE_ACCESS_TOKEN="..." \
  SQUARE_WEBHOOK_SIGNATURE_KEY="..." \
  WISE_API_TOKEN="..." \
  TREASURY_ETH_WALLET="0x9505578Bd5b32468E3cEa632664F7b8d2e46128c"

# Kairo identity
vault kv put secret/yieldswarm/production/kairo \
  IOTEX_PRIVATE_KEY="(TEE)" \
  WALLET_ENCRYPTION_KEY="..." \
  TEE_SIGNING_KEY="..."
```

### 2b. Create AppRole for Akash deployments

```bash
vault auth enable approle
vault policy write yieldswarm-deploy - <<EOF
path "secret/data/yieldswarm/production/*" {
  capabilities = ["read"]
}
EOF

vault write auth/approle/role/yieldswarm-deploy \
  token_policies="yieldswarm-deploy" \
  token_ttl=1h

vault read auth/approle/role/yieldswarm-deploy/role-id
vault write -f auth/approle/role/yieldswarm-deploy/secret-id
```

### 2c. Vault Agent config (inside container)

See `deploy/vault/agent.hcl` — mounted at deploy time.

---

## Step 3: Build Container Images

```bash
# From repo root
docker build -t yieldswarm/api-gateway:2.0.0 -f services/api/Dockerfile services/api
docker build -t yieldswarm/odysseus:2.0.0 -f services/odysseus/Dockerfile services/odysseus
docker build -t yieldswarm/kairo-identity:2.0.0 -f services/kairo-identity/Dockerfile services/kairo-identity
docker build -t yieldswarm/payments:2.0.0 -f services/payments/Dockerfile services/payments
docker build -t yieldswarm/health-sidecar:2.0.0 -f services/health-sidecar/Dockerfile services/health-sidecar

# Push to registry (replace with your registry)
docker tag yieldswarm/api-gateway:2.0.0 ghcr.io/yieldswarm/api-gateway:2.0.0
docker push ghcr.io/yieldswarm/api-gateway:2.0.0
# Repeat for each service
```

---

## Step 4: Deploy to Akash

```bash
# Set Vault + Akash credentials (never commit these)
export VAULT_ADDR="https://vault.yieldswarm.crypto"
export VAULT_ROLE_ID="<role-id>"
export VAULT_SECRET_ID="<secret-id>"
export AKASH_KEY_NAME="yieldswarm-deploy"
export AKASH_CHAIN_ID="akashnet-2"
export AKASH_NODE="https://rpc.akash.network:443"
export AKASH_DEPOSIT="5000000"

# Dry run first
./scripts/akash-deploy.sh --env production --dry-run

# Full deploy
./scripts/akash-deploy.sh --env production
```

Expected output:
```
[akash-deploy] Pulling secrets from Vault (env: production)...
[akash-deploy] SDL validation passed
[akash-deploy] Deployment created — DSEQ: 12345678
[akash-deploy] Health checks passed
[akash-deploy] Deployment complete
```

---

## Step 5: Verify Deployment

```bash
# Health checks (local or remote)
./scripts/health-check.sh --env production --url https://api.yieldswarm.crypto

# Check Akash lease status
akash query deployment list --owner $(akash keys show yieldswarm-deploy -a)
akash provider lease-status --dseq <DSEQ>

# Odysseus agent count
curl https://api.yieldswarm.crypto/api/v1/odysseus/agents/stats

# Kairo identity smoke test
curl -X POST https://api.yieldswarm.crypto/api/v1/kairo/drivers/register \
  -H "Content-Type: application/json" \
  -d '{"deviceId":"test-device-001","platform":"ios"}'
```

---

## Step 6: Wire DNS

See [DOMAINS.md](./DOMAINS.md) for Unstoppable Domains + Cloudflare records.

Minimum records after deploy:
- `api.yieldswarm.crypto` → Akash ingress URI
- `dashboard.yieldswarm.crypto` → Vercel
- `app.yieldswarm.crypto` → Kairo app (future)

---

## Auto-Healing

The `health-sidecar` service:
- Polls all internal services every 30s
- Restarts unhealthy containers via Akash lease manager API
- Alerts via `ERROR_WEBHOOK` (configure in Vault)

Manual heal:
```bash
curl -X POST https://api.yieldswarm.crypto/api/v1/akash/leases/heal \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

---

## Rollback

```bash
./scripts/akash-deploy.sh --rollback --env production
```

This closes the current Akash deployment and archives lease state to `.akash-state/`.

---

## Environment Matrix

| Branch | `--env` flag | Vault path prefix | Public URL |
|--------|-------------|-------------------|------------|
| `development` | `development` | `yieldswarm/development/` | `localhost:3000` |
| `testnet` | `testnet` | `yieldswarm/testnet/` | `api-testnet.yieldswarm.crypto` |
| `devnets` | `devnets` | `yieldswarm/devnets/` | Per-shard subdomain |
| `production` | `production` | `yieldswarm/production/` | `api.yieldswarm.crypto` |
| `MAINNET` | `MAINNET` | `yieldswarm/MAINNET/` | `api.yieldswarm.crypto` |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| SDL validation fails | Check `deploy/deploy-swarm-monolith.yaml` syntax; run `akash tx deployment validate` |
| No provider bids | Increase `AKASH_DEPOSIT`; verify GPU attribute matches RTX 3090 |
| Vault auth fails | Rotate AppRole secret; verify `VAULT_ADDR` reachable from Akash |
| Health checks timeout | Wait 2–5 min for Ollama model pull; check `akash provider lease-logs` |
| Ollama OOM | Reduce model size in SDL env `OLLAMA_MODELS` |

---

## Security Checklist

- [ ] All secrets in Vault — nothing in `.env` committed
- [ ] AppRole tokens TTL ≤ 1h
- [ ] `NETWORK_LOCKDOWN_MODE=true` on MAINNET
- [ ] Webhook signature verification enabled (Square, Wise)
- [ ] TEE signing keys air-gapped
- [ ] Immunefi scope updated for new contracts
