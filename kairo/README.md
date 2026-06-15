# Kairo — Driver-first marketplace node for YieldSwarm

Kairo turns every driver into a cryptographically identified YieldSwarm node.
Signed driving telemetry flows into the Mandelbrot / Tree of Life reward mesh.

## Features

- **Persistent identity** — secp256k1 keys with EVM (`0x…`) and IoTeX (`io1…`) addresses
- **Signed telemetry** — EIP-191 signed driving packets
- **Mandelbrot pipeline** — shard/branch/leaf indexing for DePIN rewards
- **Earnings breakdown** — app revenue (2× pay) + crypto/DePIN rewards (1% customer fee)

## Telemetry pipeline

See **`KAIRO_TELEMETRY.md`** for the full collect → sign → Mandelbrot → reward flow.

```bash
# Simulate a drive (3 GPS points)
python kairo/cli.py simulate-drive '{"driver_id":"driver-demo-1"}'

# Batch ingest
curl -s -X POST http://localhost:8091/api/telemetry/batch \
  -H 'Content-Type: application/json' \
  -d '{"samples":[{"driver_id":"driver-demo-1","latitude":39.74,"longitude":-104.99,"speed_kmh":40}]}'
```

## Quick start

```bash
pip install -r requirements.txt
python -m kairo.api.routes
```

### Register a driver

```bash
curl -s -X POST http://localhost:8091/api/drivers \
  -H 'Content-Type: application/json' \
  -d '{"driver_id":"driver-demo-1"}'
```

### Submit signed telemetry

```bash
curl -s -X POST http://localhost:8091/api/telemetry \
  -H 'Content-Type: application/json' \
  -d '{
    "driver_id": "driver-demo-1",
    "payload": {
      "latitude": 39.7392,
      "longitude": -104.9903,
      "speed_kmh": 42.5,
      "distance_km": 3.2,
      "duration_seconds": 280
    }
  }'
```

### Contribution dashboard

Open `kairo/dashboard/contribution.html` or query:

```bash
curl -s http://localhost:8091/api/drivers/driver-demo-1/contribution?trip_fare_usd=24.50
curl -s http://localhost:8091/api/contribution/leaderboard
```

## Integration

| System | Path |
|--------|------|
| Payment rails | `src/lib/payments/` (Square, Wise, Web3) |
| Unified wallet | `frontend/src/wallet/` |
| Odysseus memory | `agents/odysseus_memory.py` (optional fan-out) |
| Backend proxy | `backend/src/adapters/kairo.js` |

## Environment

```bash
KAIRO_API_HOST=0.0.0.0
KAIRO_API_PORT=8091
KAIRO_STORE_DIR=.data/kairo
KAIRO_IDENTITY_ENCRYPTION_KEY=   # or WALLET_ENCRYPTION_KEY
KAIRO_CUSTOMER_FEE_RATE=0.01
KAIRO_DRIVER_PAY_MULTIPLIER=2.0
KAIRO_DEPIN_REWARD_PER_WEIGHT=0.0025
```
