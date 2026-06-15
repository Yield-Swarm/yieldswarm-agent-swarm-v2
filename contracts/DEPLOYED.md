# Great Delta Emission Router — deployment registry

Canonical contract: [`GreatDeltaEmissionRouter.sol`](./GreatDeltaEmissionRouter.sol)

## Split policy (50/30/15/5)

| Index | Canonical bucket   | BPS  | Legacy alias (quadrant-IV) |
|-------|--------------------|------|----------------------------|
| 0     | `coreTreasury`     | 5000 | `vault`                    |
| 1     | `growthTreasury`   | 3000 | `operations`               |
| 2     | `insuranceTreasury`| 1500 | `ecosystem`                |
| 3     | `opsTreasury`      | 500  | `sovereignReserve`         |

## Deploy

```bash
# Set GD_SIGNER_0..2, GD_TREASURY_* , GD_BASE_EMISSION_WEI, DEPLOYER_PRIVATE_KEY
bash scripts/deploy_great_delta_router.sh
```

Foundry script: `scripts/DeployGreatDeltaEmissionRouter.s.sol`

## Environment (integration backend)

| Variable | Purpose |
|----------|---------|
| `SPLIT_CORE_BPS` / `SPLIT_GROWTH_BPS` / `SPLIT_INSURANCE_BPS` / `SPLIT_OPS_BPS` | Off-chain treasury split (default 5000/3000/1500/500) |
| `EMISSION_ROUTER_ADDRESS` | Solana emission router account for RPC telemetry |
| `TREASURY_ADDRESS` | Solana treasury wallet for balance splits |
| `EMISSION_ROUTER_EVM_ADDRESS` | Deployed EVM router for `eth_call` preview |
| `EVM_RPC_URL` / `MAINNET_RPC_URL` | JSON-RPC endpoint for EVM reads |
| `EVM_ENABLED` | Set `1` to enable EVM adapter |

## API surfaces

- Integration backend: `GET /api/great-delta/overview`, `POST /api/great-delta/telemetry`
- DePIN worker (FastAPI): `GET /api/great-delta/health` on port 8080 inside worker container

## Deprecated

`contracts/quadrant-iv/GreatDeltaEmissionRouter.sol` uses legacy bucket names with the same ratios. **Do not deploy for mainnet** — use the root canonical contract above.

## Deployments

| Network | Address | Tx | Date |
|---------|---------|----|------|
| _(unset)_ | — | — | — |

_Update this table after mainnet/testnet deploy._
