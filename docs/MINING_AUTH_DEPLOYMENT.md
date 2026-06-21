# Mining Auth + Production Deployment (Prompt 37)

Deploys secure mining auth using Vault-seeded secrets, connects Azure/Akash/local fleet to funded wallets, and routes rewards to TAO, SOL, and other payout addresses.

## Quick deploy

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=...                    # or AppRole via akash-vault-prepare
export AGENTSWARM_MASTER_KEY=...           # from Vault runtime/core
chmod +x scripts/deploy-mining-production.sh
./scripts/deploy-mining-production.sh
```

## Auth

| Component | Purpose |
|-----------|---------|
| `mining/auth.py` | HMAC tokens signed with `AGENTSWARM_MASTER_KEY` |
| `vault/policies/mining-runtime.hcl` | Read mining + wallet paths |
| `GET /api/mining/auth` | Auth bootstrap status |
| `MINING_AUTH_SKIP=1` | Dev only — disables gate |

Vault loads ~88 secrets via paths in `vault/scripts/seed-secrets.sh`. Mining deploy injects:

- `mining/wallets`
- `runtime/bittensor`
- `runtime/wallets`
- `runtime/core`
- `runtime/akash`

## Reward routing

| Coin | Env wallet |
|------|------------|
| TAO | `MINING_ROOT_TAO` |
| SOL | `NEXUS_TREASURY_SOLANA` / `TREASURY_ADDRESS` |
| ETC | `MINING_ROOT_BASE_ETC` |
| XMR | `MONERO_WALLET_ADDRESS` |
| ZEC | `MINING_ROOT_ZEC` |
| IoTeX/BTC | `IOTEX_TREASURY`, `IOTEX_BTC_BRIDGE` |

`GET /api/mining/rewards` — live routing table  
Great Delta 50/30/15/5 split applied on aggregated USD revenue.

## Fleet (Azure + Akash + local)

```json
MINING_FLEET_INSTANCES=[
  {"id":"akash-gpu-1","provider":"akash","miners":["bittensor"]},
  {"id":"azure-cpu-1","provider":"azure","miners":["monero","etc"]},
  {"id":"local-depin-1","provider":"local","miners":["grass","helium"]}
]
```

## API

| Method | Path | Auth |
|--------|------|------|
| GET | `/api/mining/auth` | — |
| GET | `/api/mining/status` | — |
| GET | `/api/mining/rewards` | — |
| POST | `/api/mining/deploy` | Bearer `AGENTSWARM_MASTER_KEY` |
| POST | `/api/mining/start` | Bearer |
| POST | `/api/mining/stop` | Bearer |

## CLI

```bash
python3 -m mining deploy --json
./scripts/mining/status.sh
```

See also: `docs/MINING_INFRASTRUCTURE.md`
