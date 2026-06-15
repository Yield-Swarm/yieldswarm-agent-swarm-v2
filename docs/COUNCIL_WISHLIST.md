# Council Wishlist — Recommended Additional Services

> Status: June 2026 · **8 services** the 14-Council recommends adding when ready.  
> **Never commit API keys.** Seed via HashiCorp Vault (`vault/scripts/seed-secrets.sh`).

| Service | Env vars | Vault path | Best for |
|---------|----------|------------|----------|
| **QuickNode** | `QUICKNODE_API_KEY`, `QUICKNODE_RPC_URL` | `integrations/quicknode` | Multi-chain RPC redundancy (15+ chains) |
| **Tenderly** | `TENDERLY_API_KEY`, `TENDERLY_ACCOUNT`, `TENDERLY_PROJECT` | `integrations/tenderly` | Arena contract simulation + tx debugging |
| **Sentry** | `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE` | `integrations/sentry` | Production error tracking + performance |
| **Cloudflare** | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_CLIENT_ID`, `CLOUDFLARE_CLIENT_SECRET`, `CLOUDFLARE_ZONE_ID` | `integrations/cloudflare` | CDN, DDoS, R2, Workers, Access |
| **Pinata** | `PINATA_API_KEY`, `PINATA_SECRET`, `PINATA_JWT` | `integrations/pinata` | IPFS pinning for agent artifacts + lore |
| **Livepeer** | `LIVEPEER_API_KEY` | `integrations/livepeer` | Decentralized video (AMAs, education) |
| **Infura** | `INFURA_PROJECT_ID`, `INFURA_API_KEY`, `INFURA_SOL_MAINNET_RPC` | `rpc/infura` | Ethereum + Solana RPC (already partially wired) |
| **Ankr** | `ANKR_API_KEY`, `ANKR_RPC_MULTICHAIN` | `rpc/ankr` | Multichain RPC fallback |

## Enable checklist

1. Create keys in each provider dashboard.
2. Export vars locally (never commit):
   ```bash
   export QUICKNODE_API_KEY=...
   export TENDERLY_API_KEY=...
   # etc.
   ```
3. Seed Vault:
   ```bash
   export VAULT_ADDR=... VAULT_TOKEN=...
   ./vault/scripts/seed-secrets.sh
   ```
4. Verify Akash runtime injection via `akash/vault-agent/templates/env.ctmpl`.
5. Add Sentry SDK per `docs/SENTRY.md` when ready (optional).

## Security

If any key was pasted into chat, email, or committed to git — **rotate immediately** in the provider dashboard and re-seed Vault. Treat chat logs as compromised.
