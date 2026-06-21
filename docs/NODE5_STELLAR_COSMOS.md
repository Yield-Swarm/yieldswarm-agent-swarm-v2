# Node 5 — PyHackathon Stellar + Cosmos SDK

Production module for cross-chain Stellar (XLM) and Cosmos SDK operations.

## Layout

```text
nodes/node5/
├── config.py          # env / Vault loader
├── orchestrator.py    # run_cycle() — main entrypoint
├── stellar/client.py  # Horizon + stellar-sdk payments
└── cosmos/client.py   # Cosmos REST bank queries
```

## Secrets (SecretProd.pdf → Vault only)

**Never commit** `SecretProd.pdf` or raw keys. Map PDF values to Vault, then inject as env:

| Env var | Vault key (`yieldswarm/node5/stellar`) | Purpose |
|---------|----------------------------------------|---------|
| `STELLAR_SECRET_KEY` | `secret_key` | Signer secret (starts with `S...`) |
| `STELLAR_PUBLIC_KEY` | `public_key` | Account public key (starts with `G...`) |
| `STELLAR_DESTINATION_ADDRESS` | `destination` | Treasury / payout address |
| `STELLAR_NETWORK` | `network` | `public` or `testnet` |
| `STELLAR_HORIZON_URL` | `horizon_url` | Optional Horizon override |

| Env var | Vault key (`yieldswarm/node5/cosmos`) | Purpose |
|---------|----------------------------------------|---------|
| `COSMOS_MNEMONIC` | `mnemonic` | Wallet mnemonic (live txs) |
| `COSMOS_ADDRESS` | `address` | Bech32 address (`akash1...`) |
| `COSMOS_CHAIN_ID` | `chain_id` | e.g. `akashnet-2` |
| `COSMOS_REST_URL` | `rest_url` | Cosmos REST base URL |

Seed from operator env:

```bash
export STELLAR_SECRET_KEY=...   # from SecretProd.pdf
export STELLAR_PUBLIC_KEY=...
export COSMOS_MNEMONIC=...
./vault/scripts/seed-secrets.sh
```

## Orchestrator integration

### Sovereign loop (`swarm_runner.py`)

`agents/node5_orchestrator.py` runs each tick. State: `.run/node5-last-run.json`

### Cross-chain executor

Strategy kind `stellar_cosmos` registered in `services/cross_chain/strategies/stellar_cosmos.py`.

### Direct Python

```python
from nodes.node5 import run_cycle

report = run_cycle(actions=["status", "balance"])
```

## Dependencies

```bash
pip install stellar-sdk cosmpy   # optional for live txs
```

Dry-run works with stdlib only (Horizon + Cosmos REST reads).

## Enable live mode

```bash
NODE5_ENABLED=1
NODE5_DRY_RUN=0
CROSS_CHAIN_DRY_RUN=0
STELLAR_SECRET_KEY=...   # from Vault
STELLAR_PUBLIC_KEY=...
```

## God Task #5

White-box node bootstrap — Node 5 module satisfies PyHackathon Stellar + Cosmos wiring for the MacBook / HQ relay stack.
