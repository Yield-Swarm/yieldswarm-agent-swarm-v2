# Akash Mainnet Deployment Guide

Deploy the YieldSwarm AgentSwarm monolith on **Akash Mainnet** with **JWT authentication** (AEP-64) and **HashiCorp Vault** runtime secret injection.

## Prerequisites

| Requirement | Minimum |
|-------------|---------|
| Akash wallet | ≥ 0.5 AKT on mainnet |
| `provider-services` CLI | v0.10+ (v0.14 recommended) |
| Vault | AppRole credentials for `akash-runtime` |
| Container image | Public registry pullable by Akash providers |

## 1. Install provider-services

```bash
curl -sfL https://raw.githubusercontent.com/akash-network/provider/main/install.sh | bash
export PATH="$PWD/bin:$PATH"
provider-services version
# Expected: v0.10.0 or higher
```

## 2. Configure secrets (Vault + Codespace)

### Option A — Vault (production)

```bash
export VAULT_ADDR=https://vault.yieldswarm.internal:8200
export VAULT_ROLE_ID=$(vault read -field=role_id auth/approle/role/akash-runtime/role-id)
export VAULT_SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/akash-runtime/secret-id)

vault kv put yieldswarm/akash \
  auth_method="jwt" \
  key_name="yieldswarm-admin" \
  keyring_backend="test" \
  wallet_mnemonic="YOUR 24-WORD MNEMONIC HERE" \
  account_address="akash1..." \
  rpc_endpoint="https://rpc.akt.dev/rpc" \
  chain_id="akashnet-2" \
  gas_prices="0.025uakt"
```

### Option B — Codespace environment (quick start)

```bash
export AKASH_KEY_NAME="yieldswarm-admin"
export AKASH_KEYRING_BACKEND="test"
export AKASH_WALLET_MNEMONIC="your 24-word mnemonic here"
export VAULT_ADDR="http://127.0.0.1:8200"
export VAULT_ROLE_ID="..."
export VAULT_SECRET_ID="..."
```

> JWT is **automatic** — `provider-services` signs with your key and mints short-lived tokens. You do **not** need to export `AKASH_JWT` manually.

## 3. Verify environment

```bash
chmod +x deploy/akash/*.sh deploy/akash/lib/*.sh
./deploy/akash/verify-env.sh
```

Expected output includes:
- `provider-services` installed
- `Auth: jwt (provider-services auto-JWT enabled)`
- `balance >= 0.5 AKT`

## 4. Build and push container image (for Vault monolith)

```bash
docker build -f deploy/akash/Dockerfile -t ghcr.io/yield-swarm/agentswarm-akash:latest .
docker push ghcr.io/yield-swarm/agentswarm-akash:latest
```

For a **quick first lease** without a custom image:

```bash
export DEPLOY_IMAGE="nginx:1.27-alpine"
export CONTAINER_PORT=80
```

## 5. Deploy (full pipeline)

One command runs the entire flow:

```bash
./deploy/akash/deploy-full.sh
```

This executes:

| Step | Action |
|------|--------|
| 1 | `tx deployment create` — submit SDL to chain |
| 2 | `query market bid list` — wait for provider bids |
| 3 | `tx market lease create` — accept bid (prefers **europlots**) |
| 4 | `send-manifest` — push workload (auto-JWT to provider) |
| 5 | Health probe via `monitor-lease.sh` |

### Options

```bash
# Prefer europlots (default: akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc)
./deploy/akash/deploy-full.sh --provider akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc

# Use a specific public image
./deploy/akash/deploy-full.sh --image nginx:1.27-alpine

# Cap max bid price
./deploy/akash/deploy-full.sh --max-bid-uakt 3000
```

### Preferred provider (europlots)

| Provider | Address | Host |
|----------|---------|------|
| europlots (mainnet) | `akash18ga02jzaq8cw52anyhzkwta5wygufgu6zsz6xc` | `provider.europlots.com` |

Override with `PREFERRED_PROVIDER` or `--provider`.

## 6. Monitor lease health

```bash
# One-shot status + HTTP health check
./deploy/akash/monitor-lease.sh

# Wait until healthy (post-deploy)
./deploy/akash/monitor-lease.sh --wait

# Continuous monitoring (every 30s)
./deploy/akash/monitor-lease.sh --watch
```

### CLI monitoring

```bash
export PATH="$PWD/bin:$PATH"
source deploy/akash/setup-auth.sh && configure_akash_auth

DSEQ=$(jq -r .dseq deploy/.akash-deployment.json)
PROVIDER=$(jq -r .provider deploy/.akash-deployment.json)

provider-services lease-status \
  --dseq "$DSEQ" --provider "$PROVIDER" \
  --from "$AKASH_KEY_NAME" --keyring-backend "$AKASH_KEYRING_BACKEND"

provider-services lease-logs \
  --dseq "$DSEQ" --provider "$PROVIDER" \
  --from "$AKASH_KEY_NAME" --keyring-backend "$AKASH_KEYRING_BACKEND"
```

## 7. SDL reference

Template: [`deploy/deploy-swarm-monolith.yaml`](deploy-swarm-monolith.yaml)

Rendered at deploy time with `envsubst` — **never commit rendered SDL** (contains Vault AppRole secret_id).

Runtime secrets injected inside the container via `entrypoint.sh`:
- `yieldswarm/akash` — wallet config, agent keys
- `yieldswarm/rpc` — Solana RPC endpoints
- `yieldswarm/runpod` — GPU cluster keys

Health endpoint: `GET /health` on container port 8080 (exposed as port 80 globally).

## 8. JWT authentication explained

| Layer | Mechanism |
|-------|-----------|
| **Chain txs** (create deployment, lease) | Signed with keyring key via `provider-services tx` |
| **Provider API** (send-manifest, lease-status) | Auto-JWT minted by CLI (AEP-64) |
| **Container runtime** | Vault AppRole → KV secrets → env vars |

No private keys or JWTs are stored in git, SDL templates, or Docker images.

## 9. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `invalid mnemonic` | Set real mnemonic in Vault or `AKASH_WALLET_MNEMONIC` |
| `balance < 0.5 AKT` | Fund wallet shown by `verify-env.sh` |
| `no bids received` | Increase `MAX_BID_UAKT` or wait longer (`BID_WAIT_SECS=180`) |
| `send-manifest failed` | Ensure provider-services ≥ v0.10; JWT is default |
| Health check fails | Run `monitor-lease.sh --wait`; check `lease-logs` |
| Image pull error | Use a public image or push to accessible registry |

## 10. Close deployment

```bash
DSEQ=$(jq -r .dseq deploy/.akash-deployment.json)

provider-services tx deployment close \
  --dseq "$DSEQ" \
  --from "$AKASH_KEY_NAME" \
  --keyring-backend "$AKASH_KEYRING_BACKEND" \
  --node "$AKASH_NODE" \
  --chain-id "$AKASH_CHAIN_ID" \
  -y
```

## Quick copy-paste (Codespace)

```bash
export PATH="$PWD/bin:$PATH"
export AKASH_KEY_NAME="yieldswarm-admin"
export AKASH_KEYRING_BACKEND="test"
# export AKASH_WALLET_MNEMONIC="..."  # if not in Vault
# export VAULT_ADDR / VAULT_ROLE_ID / VAULT_SECRET_ID

./deploy/akash/verify-env.sh && ./deploy/akash/deploy-full.sh
```

See also: [SECRETS.md](SECRETS.md) for Vault bootstrap and secret rotation.
