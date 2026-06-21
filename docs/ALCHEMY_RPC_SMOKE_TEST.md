# Alchemy multi-chain RPC smoke test

Vault-backed health checker for **Christopher's First App** across all Alchemy Node API networks (167 chains in registry; refresh via `npm run alchemy:registry`).

## Security

- **Never** hardcode `ALCHEMY_API_KEY` in source, tests, or commits.
- Seed Vault only:

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=...   # admin, one-time seed
export ALCHEMY_API_KEY=...   # from Alchemy dashboard — shell only, not git
./vault/scripts/seed-secrets.sh
```

Vault paths:

| Path | Key |
|------|-----|
| `yieldswarm/rpc/ethereum` | `alchemy_api_key` |
| `yieldswarm/integrations/alchemy` | `api_key` |

Runtime auth: `VAULT_TOKEN`, AppRole (`VAULT_ROLE_ID` + `VAULT_SECRET_ID`), or wrapped SecretID.

Optional prefix validation (non-fatal) — set in shell only, never commit:

```bash
export ALCHEMY_KEY_PREFIX_HINT=<first-12-chars-of-your-alchemy-key>
```

## Run smoke test

```bash
# Full run (all networks, concurrent)
export VAULT_ADDR=... VAULT_TOKEN=...
npm run alchemy:smoke

# Config check without RPC
python3 scripts/alchemy/rpc-smoke-test.py --dry-run-config

# Subset
python3 scripts/alchemy/rpc-smoke-test.py --limit 10 --family evm

# Reports
# → reports/alchemy-rpc-smoke-<timestamp>.html
# → reports/alchemy-rpc-smoke-<timestamp>.json
```

## Per-chain checks

| Check | EVM | Solana | Starknet | Bitcoin | Sui | Aptos |
|-------|-----|--------|----------|---------|-----|-------|
| Chain / network ID | `eth_chainId` | `solana` | `starknet_chainId` | `bitcoin` | `sui` | `aptos` |
| Latest block / slot | `eth_blockNumber` | `getSlot` | `starknet_blockNumber` | `getblockcount` | checkpoint seq | ledger height |
| Block moving | two samples | two slots | two blocks | two heights | two checkpoints | ledger |
| Read call | balance / gas | balance | — | — | — | — |
| Rate limit (light) | 3 rapid calls | ✓ | ✓ | ✓ | ✓ | ✓ |
| Retry | exponential backoff, 3 attempts | ✓ | ✓ | ✓ | ✓ | ✓ |

Exit code `1` if any chain fails (CI-friendly).

## Architecture

```
lib/secrets.py              # shared Vault KV reader
services/alchemy/
  vault_client.py           # get_alchemy_api_key()
  network_registry.py       # config/alchemy/networks.json
  rpc_probes.py             # family-specific JSON-RPC probes
  health_checker.py         # thread pool orchestrator
  report.py                 # CLI table + HTML dashboard
scripts/alchemy/
  rpc-smoke-test.py         # CLI entry
  generate-network-registry.py
config/alchemy/networks.json
```

## Registry refresh

When Alchemy adds networks, regenerate from the [Node supported chains](https://www.alchemy.com/docs/reference/node-supported-chains) table:

```bash
npm run alchemy:registry
```
