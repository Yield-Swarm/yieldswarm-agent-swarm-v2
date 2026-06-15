# Kairo — driver-first marketplace for YieldSwarm DePIN

Kairo turns every driver into a cryptographically identified YieldSwarm node.

## Modules

| Path | Purpose |
|------|---------|
| `kairo/identity/` | Persistent IoTeX + EVM driver addresses |
| `kairo/telemetry/` | Signed driving telemetry collection |
| `kairo/pipeline/` | Mandelbrot / Tree of Life data routing |
| `kairo/payments/` | 1% customer fee, 2x driver pay, instant cashout |
| `kairo/api/` | REST API routes (mounted on backend server) |
| `kairo/dashboard/` | Driver contribution + rewards dashboard |

## Quick start

```bash
pip install eth-account
python -m kairo.api.server   # starts on :3001
```

## Integration with YieldSwarm

- Shares `frontend/src/wallet` for unified Web3
- Uses `src/lib/payments` for Square/Wise/Web3 rails
- Telemetry ingested via `/api/kairo/telemetry` → ChromaDB + Mandelbrot shards
- Driver rewards flow through Great Delta emission router
