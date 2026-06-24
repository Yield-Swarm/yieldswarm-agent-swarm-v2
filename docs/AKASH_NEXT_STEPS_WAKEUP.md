# Akash + RunPod — wakeup execution block

> Run this after rest when wallet is funded and Vault token is ready.

## Track 2 — Akash (first live lease)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<your-vault-token>   # never commit
export AGENT_SHARD_ID=0
export BT_NETUID=1

make akash-preflight          # must print GO
make deploy-akash-europlots
make akash-verify
source .run/akash-lease.env

# Arena with live workers:
# /arena?workers=${AKASH_WORKER_URLS}
```

## Track 1 — RunPod multiminer (parallel yield)

```bash
# Wallets from Vault or export (never paste in chat)
export KASPA_WALLET_ADDRESS=<your-kaspa-address>
export MONERO_WALLET_ADDRESS=<your-xmr-address>
export QUBIC_WALLET_ADDRESS=<your-qubic-address>   # optional

# Fix SSH first — see docs/RUNPOD_SSH_SETUP.md
export RUNPOD_SSH_KEY=~/.ssh/id_ed25519

./scripts/runpod_fleet_deploy.sh
./scripts/runpod_fleet_verify.sh
```

## Master hotload (local + fleet)

```bash
export MINING_DRY_RUN=0
./scripts/multiminer-hotload.sh
```

## 4 God Tasks + Solenoid

```bash
./scripts/god-task-solenoid-hotload.sh
```

## API checks

```bash
curl -s http://127.0.0.1:8080/api/mining/profitability | jq .
curl -s http://127.0.0.1:8080/api/mining/hashpower | jq .
curl -s 'http://127.0.0.1:8080/api/depin/consensus?rounds=100' | jq .
```
