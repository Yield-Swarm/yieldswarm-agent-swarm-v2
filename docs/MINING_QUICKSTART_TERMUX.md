# Mining Quickstart — Azure Cloud Shell & Termux

Use this when you're in `~` (home), not inside the repo, and commands fail because paths don't exist yet.

## Step 0 — Clone and enter the repo

```bash
cd ~/yieldswarm-agent-swarm-v2 2>/dev/null || {
  echo "Cloning fresh repo..."
  git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git ~/yieldswarm-agent-swarm-v2
  cd ~/yieldswarm-agent-swarm-v2
}
pwd
ls -la | head -10
```

Or run the automated bootstrap:

```bash
./scripts/bootstrap-mining-shell.sh
```

## Step 1 — Operator env (one time)

```bash
cp deploy/akash.env.example deploy/akash.env
nano deploy/akash.env
```

Set at minimum:

| Variable | Example |
|----------|---------|
| `AKASH_OWNER_ADDRESS` | `akash1...` your wallet |
| `AKASH_KEY_NAME` | `yieldswarm` |
| `BT_NETUID` | `1` |
| `BT_NETWORK` | `finney` |
| `VAULT_ADDR` | `https://vault.yieldswarm.io:8200` |
| `VAULT_TOKEN` | operator token (or use AppRole via `akash-vault-prepare.sh`) |

`deploy/akash.env` is **gitignored** — never commit wallet or Vault tokens.

## Step 2 — Spin up mining (one command)

```bash
chmod +x scripts/start-mining.sh
./scripts/start-mining.sh
```

This prefers `scripts/deploy-bittensor.sh` (Vault-wrapped) when `VAULT_ADDR` is set, otherwise falls back to:

```bash
./scripts/deploy-to-akash.sh deploy deploy/akash-bittensor-miner.sdl.yml
```

## What's already in the repo (don't nano-create)

| File | Status |
|------|--------|
| `deploy/akash-bittensor-miner.sdl.yml` | Production SDL (Vault sidecar, RTX 3090/4090) |
| `deploy/deploy-swarm-monolith.yaml` | 3× GPU monolith |
| `scripts/deploy-to-akash.sh` | Full Akash lifecycle |
| `scripts/deploy-bittensor.sh` | Vault + Bittensor deploy |
| `next.config.mjs` | Next.js + `/api/telemetry` rewrite |
| `mining/` | Python unified mining manager |

## Termux notes

```bash
pkg update && pkg install git nodejs-lts python
git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git
cd yieldswarm-agent-swarm-v2
./scripts/bootstrap-mining-shell.sh
```

Install Akash CLI separately — see [Akash install docs](https://akash.network/docs/deployments/akash-cli/install).

## Azure Cloud Shell notes

Cloud Shell is **ephemeral**. Use it to test bootstrap, then copy `deploy/akash.env` to Termux:

```bash
cat deploy/akash.env   # paste into Termux nano
```

## After deploy

```bash
# Status
cat .run/akash-bittensor-deploy.json 2>/dev/null || cat .run/akash-deploy.json

# Arena dashboard
# https://<your-vercel-app>/arena?workers=https://<lease-uri>:8080

# Unified mining fleet (local / Vault)
./scripts/deploy-mining-production.sh
./scripts/mining/status.sh
```

## Monolith or Vault sidecar next?

| Goal | Command |
|------|---------|
| Bittensor only (RTX 3090) | `./scripts/start-mining.sh` |
| Vault sidecar Bittensor | `USE_VAULT_AKASH=1 ./scripts/deploy-bittensor.sh` |
| 3× RTX 3090 monolith | `DEPLOY_SDL=deploy/deploy-swarm-monolith.yaml ./scripts/deploy-to-akash.sh deploy deploy/deploy-swarm-monolith.yaml` |

See also: `README.md` § Mine With Us · `docs/VAULT_AKASH_DEPLOY.md`
