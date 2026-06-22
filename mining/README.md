# Mining — YieldSwarm Operator Quick Reference

This directory holds the **unified mining manager** (Python) and operator docs. Akash GPU + Bittensor deploy artifacts live under `deploy/` and `scripts/`.

## Fresh shell (Azure Cloud Shell / Termux)

```bash
cd ~/yieldswarm-agent-swarm-v2 2>/dev/null || \
  git clone https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2.git ~/yieldswarm-agent-swarm-v2
cd ~/yieldswarm-agent-swarm-v2
./scripts/bootstrap-mining-shell.sh
```

## One-command Akash Bittensor miner

```bash
cp deploy/akash.env.example deploy/akash.env   # first time
nano deploy/akash.env                            # akash1... wallet, VAULT_*, BT_NETUID=1
./scripts/start-mining.sh
```

## What gets deployed

| Asset | Path |
|-------|------|
| Bittensor SDL | `deploy/akash-bittensor-miner.sdl.yml` |
| Monolith (3× GPU) | `deploy/deploy-swarm-monolith.yaml` |
| Vault deploy | `scripts/deploy-bittensor.sh` |
| Unified fleet | `scripts/deploy-mining-production.sh` |
| Mining manager | `python3 -m mining status` |

## Dashboards

| Surface | URL |
|---------|-----|
| Arena telemetry | `/arena?workers=<lease-uri>` |
| Command center | `/command-center` |
| Mining API | `GET /api/mining/status` |
| Single pane | `GET /api/single-pane/overview` |

## Pool / treasury pointers

See `README.md` § **Mine With Us** and `config/TREASURY_MANIFEST.json`.

Full guide: [`docs/MINING_QUICKSTART_TERMUX.md`](../docs/MINING_QUICKSTART_TERMUX.md)
