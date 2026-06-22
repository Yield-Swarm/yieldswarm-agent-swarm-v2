# Alchemy — Christopher's First App

Wires **164 enabled networks** from the Alchemy dashboard into YieldSwarm via env + Vault. The API key is **never committed** to git.

## Setup

```bash
# Local / Render / Akash — set in Vault or .env (rotate if exposed in chat)
export ALCHEMY_API_KEY=your_key_here
export ALCHEMY_APP_NAME="Christopher's First App"
```

When `ALCHEMY_API_KEY` is set, the backend auto-fills unset RPC env vars:

| Env var | Alchemy network |
|---------|-----------------|
| `SOLANA_RPC_URL` | solana-mainnet |
| `ETHEREUM_RPC_URL` / `EVM_RPC_URL` | ethereum-mainnet |
| `BASE_RPC_URL` / `EVM_RPC_URL_8453` | base-mainnet |
| `EVM_RPC_URL_137` | polygon-mainnet |
| `EVM_RPC_URL_42161` | arbitrum-mainnet |
| `SEPOLIA_RPC_URL` | ethereum-sepolia |

Explicit env values always win over Alchemy defaults.

## Vault

```bash
export ALCHEMY_API_KEY=...
export ALCHEMY_APP_NAME="Christopher's First App"
./vault/scripts/seed-secrets.sh
```

Path: `yieldswarm/data/integrations/alchemy`

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/rpc/alchemy/health` | Key configured? |
| `GET /api/rpc/alchemy/endpoints` | All 164 networks (URLs redacted) |
| `GET /api/rpc/alchemy/defaults` | Primary chain URLs in use |
| `GET /api/rpc/alchemy/url/:networkId` | Single network URL (redacted) |

## Manifest

- Generated: `config/alchemy/christophers-first-app.json`
- Regenerate: `python3 scripts/alchemy/build-manifest.py`

## Security

If your API key was pasted into chat or committed anywhere, **rotate it** in the [Alchemy dashboard](https://dashboard.alchemy.com/) immediately.
