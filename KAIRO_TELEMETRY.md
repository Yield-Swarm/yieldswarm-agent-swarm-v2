# Kairo Telemetry Pipeline

Signed driver telemetry flows from device → Kairo API → Mandelbrot / Tree of Life → YieldSwarm shard harvest.

## Pipeline stages

```
Driver device (GPS)
    ↓ collect
DriverTelemetrySample
    ↓ sign (EIP-191, driver identity)
SignedTelemetry
    ↓ verify
MandelbrotPipeline.ingest()  → shard / branch / leaf
    ↓
RewardLedger.record()        → depin + app earnings
    ↓
YieldSwarmEmitter.emit()     → .data/yieldswarm/harvest/shard-NNN/
```

## Data models

| Model | Path | Purpose |
|-------|------|---------|
| `DriverTelemetrySample` | `kairo/models/telemetry_packet.py` | Raw collected GPS + ride metadata |
| `SignedTelemetry` | `kairo/models/driver.py` | EIP-191 signed packet |
| `ContributionSummary` | `kairo/models/driver.py` | Aggregated rewards per driver |
| `TelemetryEvent` | `kairo/models/telemetry.py` | Legacy hash-based routing events |

## API endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/telemetry` | Submit unsigned sample (server signs) or pre-signed packet |
| POST | `/api/telemetry/batch` | Batch of samples `{ "samples": [...] }` |
| GET | `/api/drivers/{id}/contribution` | Reward summary + 2× pay estimate |
| GET | `/api/contribution/leaderboard` | Top drivers by Mandelbrot weight |

### Submit unsigned telemetry

```bash
curl -s -X POST http://localhost:8091/api/telemetry \
  -H 'Content-Type: application/json' \
  -d '{
    "driver_id": "driver-demo-1",
    "latitude": 39.7392,
    "longitude": -104.9903,
    "speed_kmh": 42.5,
    "distance_km": 3.2,
    "duration_seconds": 280,
    "fare_usd": 24.50
  }'
```

### Submit pre-signed packet

```bash
curl -s -X POST http://localhost:8091/api/telemetry \
  -H 'Content-Type: application/json' \
  -d '{
    "driver_id": "driver-demo-1",
    "payload": { "latitude": 39.74, "longitude": -104.99, "speed_kmh": 40 },
    "signature": "0x...",
    "signed_at": "2026-06-15T12:00:00Z"
  }'
```

## CLI

```bash
# Register driver (returns mnemonic once)
python kairo/cli.py register '{"driver_id":"driver-1"}'

# Simulate a drive (3 GPS points)
python kairo/cli.py simulate-drive '{"driver_id":"driver-1"}'

# Ingest raw JSON
python kairo/cli.py ingest '{"driver_id":"driver-1","latitude":39.7,"longitude":-104.9}'

# List contributions
python kairo/cli.py contributions 25
```

## Python client

```python
from kairo.client.telemetry import DriverTelemetryClient

client = DriverTelemetryClient("driver-1", api_base="http://localhost:8091")
sample = client.collect(39.7392, -104.9903, speed_kmh=35, distance_km=2.0)
result = client.submit_sample(sample)
```

## Reward tracking

- **Mandelbrot index** — `tree_index.json` (packets, distance, reward_weight per driver)
- **Reward ledger** — `reward_events.jsonl` + `reward_balances.json`
- **Earnings formula** — `kairo/services/earnings.py` (1% customer fee, 2× driver pay, DePIN weight bonus)

## YieldSwarm integration

When `KAIRO_EMIT_YIELDSWARM=true` (default), each accepted packet writes:

```
.data/yieldswarm/harvest/shard-{NNN}/kairo-{telemetry_id}.json
```

Agent shard crons consume these harvest files for DePIN reward distribution.

## Environment

```bash
KAIRO_STORE_DIR=.data/kairo
KAIRO_EMIT_YIELDSWARM=true
YIELDSWARM_HARVEST_DIR=.data/yieldswarm/harvest
KAIRO_CUSTOMER_FEE_RATE=0.01
KAIRO_DRIVER_PAY_MULTIPLIER=2.0
KAIRO_DEPIN_REWARD_PER_WEIGHT=0.0025
```
