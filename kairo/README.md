# Kairo — Driver-First Marketplace

Cryptographic identity and signed telemetry pipeline connecting every Kairo driver to the YieldSwarm Mandelbrot / Tree of Life architecture.

## Components

| Path | Purpose |
|------|---------|
| `kairo/identity/driver.py` | IoTeX + EVM compatible persistent driver addresses |
| `kairo/telemetry/signer.py` | Cryptographically signed driving telemetry batches |
| `kairo/pipeline/mandelbrot.py` | Routes signed data into Mandelbrot PoW + Tree of Life shards |
| `kairo/api/server.py` | FastAPI service (register, ingest, dashboard) |
| `kairo/dashboard/index.html` | Contribution + potential rewards dashboard |

## Quick Start

```bash
pip install -r kairo/requirements.txt
uvicorn kairo.api.server:app --host 0.0.0.0 --port 8092
# Dashboard: open kairo/dashboard/index.html (set window.KAIRO_API_URL if needed)
```

## API

- `POST /drivers/register` — create driver identity (returns private key — store in Vault)
- `POST /telemetry/ingest` — submit signed telemetry batch
- `GET /drivers/{id}` — identity + contribution summary
- `GET /dashboard/summary` — aggregate stats for dashboard

## Integration

- Shares `frontend/src/wallet/` for unified Web3 wallet
- Shares `src/lib/payments/` for 1% customer fee / 2× driver pay
- Vault path: `yieldswarm/data/kairo/drivers/<id>`
