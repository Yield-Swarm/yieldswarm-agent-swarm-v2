# Rewards Reshard / Assemble / Sweep

Helix DNA **Rewards strand** — routes pending fleet/mining revenue through Great Delta **50/30/15/5**, reshard across `config/TREASURY_MANIFEST.json` mining roots, assemble batches, and sweep to payout wallets.

## Pipeline

```text
Pending gross USD → Reshard (120 shards) → Assemble (per-wallet batches) → Sweep → Treasury roots
                              ↓
                    Great Delta 50/30/15/5
```

| Phase | Module | Output |
|-------|--------|--------|
| Reshard | `services/rewards/resharder.py` | `.run/rewards-reshard.json` |
| Assemble | `services/rewards/assembler.py` | `.run/rewards-assemble.json` |
| Sweep | `services/rewards/sweeper.py` | `.run/rewards-sweep.json` |

## API

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/api/rewards/health` | Liveness |
| `GET` | `/api/rewards/status` | Roots, phases, dry-run flag |
| `POST` | `/api/rewards/reshard` | Run reshard only |
| `POST` | `/api/rewards/assemble` | Run assemble only |
| `POST` | `/api/rewards/sweep` | Run sweep only |
| `POST` | `/api/rewards/full` | Full pipeline |

## CLI

```bash
export REWARDS_DRY_RUN=1   # default — simulated sweeps
python3 services/rewards/cli.py status
python3 services/rewards/cli.py full

./scripts/rewards/sweep-rewards.sh --full
./scripts/rewards/sweep-rewards.sh --reshard --assemble --sweep
```

## Live sweep

```bash
export REWARDS_DRY_RUN=0
export REWARDS_PENDING_USD=1000   # optional override
./scripts/rewards/sweep-rewards.sh --full
```

## MEGAPOD stub

`services/rewards/megapod_node.py` — placeholder for future Tesla MEGAPOD compute credits. Plugs into Rewards Assembler when Tesla exposes a placement API.

## Related

- `mining/rewards.py` — per-coin wallet routing
- `services/cross_chain/great_delta.py` — treasury split
- `config/TREASURY_MANIFEST.json` — mining roots
- `agents/governance/gospel.py` — `REWARDS_*` constants
