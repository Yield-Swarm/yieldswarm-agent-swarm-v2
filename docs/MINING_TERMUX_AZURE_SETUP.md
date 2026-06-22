# Mining on Termux & Azure Cloud Shell

Operator guide after cloning `yieldswarm-agent-swarm-v2`. **Do not `nano`-create SDL or deploy scripts** — they already exist in the repo.

## Fix Azure double-`~` path

```bash
cd ~
rm -rf './~/yieldswarm-agent-swarm-v2' 2>/dev/null || true
rm -rf "$HOME/~/yieldswarm-agent-swarm-v2" 2>/dev/null || true
test -d ~/yieldswarm-agent-swarm-v2 || git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git ~/yieldswarm-agent-swarm-v2
cd ~/yieldswarm-agent-swarm-v2
pwd
ls -la deploy/akash-bittensor-miner.sdl.yml scripts/deploy-to-akash.sh scripts/deploy-bittensor.sh
```

Expected: all three paths exist.

## What already exists (no manual SDL creation)

| Path | Purpose |
|------|---------|
| `deploy/akash-bittensor-miner.sdl.yml` | 1× RTX 3090 Bittensor + telemetry |
| `deploy/deploy-swarm-monolith.yaml` | Vault-hardened worker monolith |
| `deploy/akash.env.example` | Akash + Bittensor env template |
| `scripts/deploy-to-akash.sh` | Canonical Akash lifecycle |
| `scripts/deploy-bittensor.sh` | Vault wrap + Bittensor SDL deploy |
| `scripts/akash-preflight.sh` | GO/NO-GO before mainnet |
| `scripts/start-mining.sh` | One-command launcher (this guide) |
| `scripts/mining/mining-manager.sh` | Local miner fleet CLI |

## Step 1 — Env files (both Termux & Azure)

```bash
cd ~/yieldswarm-agent-swarm-v2
cp deploy/akash.env.example deploy/akash.env
cp .env.example .env
```

Edit `deploy/akash.env` (minimum):

```bash
AKASH_KEY_NAME=yieldswarm
AKASH_CHAIN_ID=akashnet-2
AKASH_NODE=https://rpc.akashnet.net:443
AKASH_AUTH_MODE=jwt
AKASH_ACCOUNT_ADDRESS=akash1YOUR_REAL_ADDRESS
BT_NETUID=1
BT_NETWORK=finney
DEPLOY_SDL=deploy/akash-bittensor-miner.sdl.yml
VAULT_ADDR=https://YOUR-CLUSTER.vault.hashicorp.cloud:8200
# VAULT_TOKEN=...   # operator only, for deploy-bittensor wrap — unset after deploy
```

Edit `.env` (dashboard / telemetry):

```bash
NEXT_PUBLIC_AKASH_GATEWAY=https://gateway.yieldswarm.crypto
ALCHEMY_API_KEY=...   # or load from Vault export
```

`deploy/akash.env` is **gitignored** — safe for local secrets.

## Step 2 — Install Akash CLI

**Termux (persistent):**

```bash
pkg update && pkg install curl wget jq -y
curl -sSL https://raw.githubusercontent.com/akash-network/akash/main/install.sh | bash
provider-services version
```

**Azure Cloud Shell (session only):**

```bash
curl -sSL https://raw.githubusercontent.com/akash-network/akash/main/install.sh | bash
export PATH="$HOME/bin:$PATH"
provider-services version
```

> Akash v0.10+ uses `provider-services` (not legacy `akash` binary). Scripts accept `AKASH_BIN=provider-services`.

## Step 3 — Wallet + preflight

```bash
cd ~/yieldswarm-agent-swarm-v2
source deploy/akash.env

# Import or create key (first time)
provider-services keys list --keyring-backend "${AKASH_KEYRING_BACKEND:-os}"

# Fund wallet with AKT (mainnet)
provider-services query bank balances "${AKASH_ACCOUNT_ADDRESS}" --node "$AKASH_NODE"

# GO/NO-GO gate
chmod +x scripts/start-mining.sh scripts/deploy-to-akash.sh scripts/deploy-bittensor.sh
./scripts/start-mining.sh preflight
```

Fix anything marked NO-GO before continuing.

## Step 4 — Deploy Bittensor miner (recommended path)

```bash
export BT_NETUID=1
export VAULT_ADDR=... 
export VAULT_TOKEN=...    # mints wrapped SecretID for bittensor-runtime AppRole
./scripts/start-mining.sh
```

Equivalent explicit command:

```bash
./scripts/deploy-bittensor.sh
```

State written to: `.run/akash-bittensor-deploy.json` and `.run/akash-lease.env`

## Step 5 — 3× RTX 3090 monolith (optional, higher budget)

```bash
./scripts/start-mining.sh monolith
# or
./scripts/deploy-to-akash.sh deploy deploy/deploy-swarm-monolith.yaml
```

Vault sidecar: `USE_VAULT_AKASH=1 ./scripts/akash-deploy-with-vault.sh`

See `docs/AKASH_SDL_BUDGETS.md` for cost tiers.

## Step 6 — Local mining manager (non-Akash miners)

```bash
./scripts/mining/mining-manager.sh config
MINING_DRY_RUN=1 ./scripts/mining/start-all.sh
./scripts/mining/mining-manager.sh start --miner bittensor
```

## Verify lease

```bash
./scripts/verify-akash-lease.sh
cat .run/akash-lease.env
curl -s "$(grep AKASH_LEASE_URI .run/akash-lease.env | cut -d= -f2)/health"
```

## Termux vs Azure

| | Termux | Azure Cloud Shell |
|---|--------|-------------------|
| Persist keys | Yes (`~/.akash` / keyring) | No — re-import each session |
| Best for | Live mining deploy | Preflight + docs only |
| Akash CLI | Install once | Re-install each login |

**Run live deploy on Termux**, not Azure Cloud Shell.

## Related docs

- `docs/MINING_INFRASTRUCTURE.md`
- `docs/AKASH_DEPLOY.md`
- `docs/VAULT_AKASH_DEPLOY.md`
- `BITTENSOR.md`
- `PRODUCTION_SPINUP.md`
