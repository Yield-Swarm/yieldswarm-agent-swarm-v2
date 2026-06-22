# Mining Quickstart — Azure Cloud Shell & Termux

Use this when you're in `~` (home), not inside the repo, and commands fail because paths don't exist yet.

## Critical: never use `\~` in the shell

| Wrong | Right |
|-------|-------|
| `cd \~/yieldswarm-agent-swarm-v2` | `cd ~/yieldswarm-agent-swarm-v2` |
| `source \~/.config/yieldswarm/nexus.env` | `source ~/.config/yieldswarm/nexus.env` |
| `tail \~/.run/mining/orchestrator.log` | `tail .run/mining/orchestrator.log` (from repo) |

A backslash before `~` makes the shell treat `~` as a **literal folder name**, which creates broken nested paths like:

```text
.../yieldswarm-agent-swarm-v2/~/yieldswarm-agent-swarm-v2/.run/mining/...
```

That breaks `nohup` and prevents Grass/Helium miners from starting.

---

## Termux — one-command mining orchestrator

```bash
# 1. Go to project (copy exactly — no backslashes)
cd ~/yieldswarm-agent-swarm-v2

# 2. Load operator config
source ~/.config/yieldswarm/nexus.env 2>/dev/null || true

# 3. Wake lock (run once per session — keeps miners alive when screen off)
termux-wake-lock

# 4. Start with logging
chmod +x scripts/mining/start-termux.sh
./scripts/mining/start-termux.sh

# 5. Check logs + status
./scripts/mining/logs-termux.sh 30
python3 -m mining status
```

Stop cleanly:

```bash
./scripts/mining/stop-termux.sh
```

Or use the manual sequence (equivalent to `start-termux.sh`):

```bash
cd ~/yieldswarm-agent-swarm-v2
source ~/.config/yieldswarm/nexus.env 2>/dev/null || true
python3 -m mining stop
sleep 2
mkdir -p .run/mining
nohup python3 -m mining start > .run/mining/orchestrator.log 2>&1 &
echo $! > .run/mining/orchestrator.pid
sleep 5
python3 -m mining status
tail -30 .run/mining/orchestrator.log
```

---

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
