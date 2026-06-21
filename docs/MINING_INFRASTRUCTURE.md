# Unified Mining Infrastructure

Production control plane for all YieldSwarm mining and DePIN workloads.

## Miners

| Miner | Env wallet | Binary / service |
|-------|------------|------------------|
| **Bittensor (TAO)** | `MINING_ROOT_TAO`, `BT_NETUID` | `agents/bittensor_miner.py` |
| **Monero (XMR)** | `MONERO_WALLET_ADDRESS` | `xmrig` |
| **Ethereum Classic** | `MINING_ROOT_BASE_ETC` | `lolMiner` / `t-rex` |
| **Grass** | `GRASS_NODE_KEYS`, `GRASS_LINEUPS` | lineup supervisor |
| **Helium** | `DEPIN_HELIUM_HOTSPOT_KEYS` | `deploy-helium-hotspot.sh` |

## CLI

```bash
chmod +x scripts/mining/*.sh

# Status all miners
./scripts/mining/status.sh

# Generate configs (dry-run safe)
./scripts/mining/mining-manager.sh config

# Start / stop
./scripts/mining/start-all.sh
./scripts/mining/stop-all.sh
./scripts/mining/mining-manager.sh start --miner bittensor
```

## Python API

```python
from mining.manager import UnifiedMiningManager

mgr = UnifiedMiningManager()
mgr.write_configs()
mgr.start()          # all miners
mgr.status()         # fleet status
mgr.stop("monero")   # single miner
```

## Grass lineups (multiplier)

Platform uptime multipliers applied automatically:

| Platform | Multiplier |
|----------|------------|
| Android | 3x |
| Linux / Windows / Mac | 2x |

Set explicit lineups via `GRASS_LINEUPS` JSON or derive from `GRASS_NODE_KEYS`.  
Example: `config/mining/grass-lineups.example.json`

**Sybil rule:** run Android lineup on separate mobile data from desktop lineups.

## Helium deployment

```bash
export DEPIN_HELIUM_HOTSPOT_KEYS='[{"model":"HNT-ODU-0012","serial":"60013006881","mac":"60:6D:3C:5F:14:1C","ssid":"Helium-5G-141C","wallet":"..."}]'
./scripts/mining/deploy-helium-hotspot.sh
```

## Sovereign loop

`agents/mining_manager_agent.py` is registered in `swarm_runner.py`.  
Set `MINING_AUTO_START=1` to auto-start stopped miners each tick.

## State files

`.run/mining/`:

- `mining-manager-status.json` — fleet snapshot
- `{miner}-config.json` — generated pool/wallet config
- `{miner}-status.json` — per-miner state
- `{miner}.pid` / `{miner}.log` — live processes

## Live mode

```bash
MINING_DRY_RUN=0
# Ensure miner binaries installed: xmrig, lolMiner
# Bittensor: BT_NETUID + Vault runtime/bittensor wallet
./scripts/mining/start-all.sh
```

## Akash GPU deploy (Bittensor)

```bash
./scripts/deploy-bittensor.sh
```

See `BITTENSOR.md` and `deploy/akash-bittensor-miner.sdl.yml`.
