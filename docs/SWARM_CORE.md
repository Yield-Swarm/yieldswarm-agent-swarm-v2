# Swarm Core — Persona Engine & Shard Accelerator

Rust-native modules for character persona profiles and the 14×14 processing layer accelerator loop.

## Layout

| File | Role |
|------|------|
| `src/dna_persona.rs` | Persona registry (elon, zuck, huberman, johnson, hartman) + memory alignment simulation |
| `src/accelerator.rs` | 14-elevator synchrotron loop with Mandelbrot backoff |
| `src/config.rs` | Env/Vault-driven production config — **no hardcoded API keys** |

## Environment

| Variable | Default |
|----------|---------|
| `AGENT_COUNT_TOTAL` | 10080 |
| `AGENTS_PER_SHARD` | 84 |
| `CRON_SHARD_COUNT` | 120 |
| `INFURA_SOL_MAINNET_RPC` / `SOLANA_RPC_URL` | — |
| `JUPITER_API_KEY` | — |
| `AZURE_PROD_LOCATION` | Australia East |
| `AZURE_BACKUP_LOCATION` | Japan East |
| `AZURE_DR_LOCATION` | Indonesia Central |

## Build

```bash
npm run swarm-core:check
```

## Security

Rotate any keys that appeared in chat or commits before production deploy. Inject replacements via HashiCorp Vault (`docs/VAULT_ENV_INJECTION.md`).
