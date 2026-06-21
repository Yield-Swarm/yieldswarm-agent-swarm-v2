# yieldswarm.blockchain — IPFS Deploy Runbook

**Run ID:** `BLOCKCHAIN-IPFS-DEPLOY-001`  
**Date:** 2026-05-22  
**Manifest:** `config/deployments/BLOCKCHAIN-IPFS-DEPLOY-001.json`

## Status

| Step | Status |
|------|--------|
| §1 Seed phrase | Wiped — never on disk / ENV / logs |
| §2 IPFS upload | Live on DHT |
| §3 Domain ownership | Verified on Polygon |
| §4 On-chain content record | **Pending** (gasless UD or 0.02 MATIC) |
| §5 HELIX ledger | Receipt recorded |
| §6 Telegram | Pending chat IDs |

## IPFS

| Field | Value |
|-------|-------|
| CID (v0) | `QmQUS42xN6Ej21baZZCMmxnirwzy9XFRPruqUYTof4vwTz` |
| CID (v1) | `bafybeia7ww22z4oewud4so4whxmqi5jbcc4cjjbqc5onb7s2myk6qnwqnu` |
| Gateways | `ipfs.io`, `cloudflare-ipfs.com`, `gateway.pinata.cloud` — path `/ipfs/{cid}` |

## Polygon / Unstoppable

| Field | Value |
|-------|-------|
| Domain | `yieldswarm.blockchain` |
| Owner | `0x7064CA664A0f0afB71E097E132eE5c0139545CAf` |
| Registry | `0xa9a6A3626993D487d2Dbda3173cf58cA1a9D9e9` |
| Token ID | `21268276313523194213174230832517790682923948778931355501543334310372290398494` |

## Finalize Web3 resolution (choose one)

### A — UD Dashboard (gasless, recommended)

1. [unstoppabledomains.com](https://unstoppabledomains.com) → My Domains → `yieldswarm.blockchain` → Manage  
2. Set **IPFS** field: `QmQUS42xN6Ej21baZZCMmxnirwzy9XFRPruqUYTof4vwTz`  
3. Save (UD meta-transaction relayer)

### B — On-chain Polygon

1. Send **0.02 MATIC** to `0x7064CA664A0f0afB71E097E132eE5c0139545CAf`  
2. Call `setMany` on registry `0xa9a6A3626993D487d2Dbda3173cf58cA1a9D9e9`:

```solidity
setMany(
  ["dweb.ipfs.hash", "ipfs.html.value"],
  ["QmQUS42xN6Ej21baZZCMmxnirwzy9XFRPruqUYTof4vwTz", "QmQUS42xN6Ej21baZZCMmxnirwzy9XFRPruqUYTof4vwTz"],
  21268276313523194213174230832517790682923948778931355501543334310372290398494
)
```

## Repo commands

```bash
# Verify gateways
bash scripts/domains/verify-ipfs-cid.sh

# Telegram §6 (after configuring chat IDs)
export TELEGRAM_BOT_TOKEN=...
export TELEGRAM_YIELDSWARM_CHAT_ID=...
bash scripts/domains/broadcast-telegram-deploy.sh
```

## HELIX ledger

Receipt: `c1c329e004c3933685e5b56dd1245c14544877398f910d1535d8f4bac81bb486`  
Append-only log: `config/deployments/helix-ledger.jsonl`  
Python API: `services/helix/deploy_ledger.py`

## Security

Never commit seed phrases, private keys, or UD signing material. Rotate any credential that appeared in chat.
