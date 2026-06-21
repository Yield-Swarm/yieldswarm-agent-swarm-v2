# Bifröst — Rainbow Bridge (IPFS + blockchain gateways)

Restores the pinned IPFS bridge between your local YieldSwarm static realm and the multi-chain identity gateways (`helixchain.blockchain`, `nexuschain.blockchain`, `shadowchain.blockchain`).

## Quick start

```bash
cp .env.example .env   # set PINATA_JWT (or PINATA_API_KEY + PINATA_SECRET)
./scripts/deploy-ipfs-blockchain.sh --dry-run
./scripts/deploy-ipfs-blockchain.sh
./scripts/deploy-ipfs-blockchain.sh --verify
```

## What it does

1. **Stages** `dashboard/`, `frontend/dist/`, and root static HTML into `.run/bifrost-staging/`
2. **Computes** a directory CID via `ipfs add -r` (kubo CLI or Docker `ipfs/kubo`)
3. **Pins** the CID on Pinata (`pinByHash`) when credentials are set
4. **Writes** `dashboard/bifrost-manifest.json` with realm → gateway mappings
5. **Updates** `dashboard/config.js` with `window.YIELDSWARM_CONFIG.bifrost`

## Environment

| Variable | Purpose |
|----------|---------|
| `PINATA_JWT` | Preferred Pinata auth for remote pin |
| `PINATA_API_KEY` / `PINATA_SECRET` | Alternate Pinata auth |
| `IPFS_GATEWAY` | Public gateway base (default Pinata) |
| `BIFROST_ROOT_CID` | Skip `ipfs add` and pin a known CID |
| `BIFROST_PIN_NAME` | Pinata metadata name |
| `API_BASE` | Local backend bridge URL in manifest |

## Flags

| Flag | Effect |
|------|--------|
| `--dry-run` | Print resolved paths + planned actions; write placeholder manifest |
| `--skip-build` | Reuse existing `frontend/dist` |
| `--skip-pinata` | Local CID only, no Pinata API calls |
| `--verify` | Check gateway reachability for existing manifest |
| `--cid <cid>` | Use explicit root CID |

## Audit log

Every run appends to `.run/deployment.log` (gitignored) with timestamps, resolved paths, and step outcomes.

## Integration

- `deploy/deploy-full-stack.sh` phase 3 runs a dry-run automatically
- Command Center reads `window.YIELDSWARM_CONFIG` when served from IPFS
- Unstoppable Domains: point `.crypto` / `.blockchain` IPFS records at `rootCid` from manifest
