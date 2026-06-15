# Kairo → YieldSwarm Bridge

Turn Kairo drivers into cryptographically verified YieldSwarm data nodes. Signed GPS telemetry flows through the **Mandelbrot fractal sharding** engine and **Tree of Life** routing layer into the AgentSwarm architecture, with DePIN reward estimates and **2× driver pay** when contribution thresholds are met.

## Architecture

```
┌─────────────┐   signed telemetry    ┌──────────────────────┐
│  Kairo App  │ ────────────────────► │  Kairo Bridge API    │
│  (driver)   │   secp256k1 / EVM     │  kairo/api/main.py   │
└─────────────┘                       └──────────┬───────────┘
       │                                         │
       │ persistent identity                     │ ingest
       │ EVM 0x… + IoTeX io1…                    ▼
       │                              ┌──────────────────────┐
       │                              │ Telemetry Pipeline   │
       │                              │ verify signature     │
       │                              │ Mandelbrot → shard   │
       │                              │ Tree of Life → node  │
       │                              └──────────┬───────────┘
       │                                         │
       ▼                                         ▼
┌─────────────┐                       ┌──────────────────────┐
│ Vault       │                       │ YieldSwarm Core      │
│ yieldswarm/ │                       │ 120 cron shards      │
│ kairo       │                       │ Helix path routing   │
└─────────────┘                       │ DePIN HNT/GRASS/AKT  │
                                      │ 2× driver pay rail   │
                                      └──────────────────────┘
```

## Quick start

```bash
# Install and run API
chmod +x kairo/run.sh
./kairo/run.sh

# Register a driver (client-side keys — recommended)
python3 kairo/client/cli.py register kairo-user-001 --save-key driver.json

# Submit signed telemetry
python3 kairo/client/cli.py submit driver.json --lat 37.7749 --lon -122.4194

# Open dashboard
open "http://127.0.0.1:8090/dashboard?driver_id=<UUID>"
```

## Driver identity (IoTeX + EVM compatible)

Both chains use **secp256k1**. One keypair yields:

| Chain | Address format | Derivation |
|-------|----------------|------------|
| EVM | `0x…` | Keccak-256 of public key (last 20 bytes) |
| IoTeX | `io1…` | Bech32(`io`, same 20-byte hash) |

### Client-side registration (production)

```http
POST /api/v1/drivers/register
Content-Type: application/json

{
  "kairo_user_id": "kairo-user-001",
  "public_key_hex": "0x04…",
  "registration_signature_hex": "0x…",
  "depin_helium_pubkey": "optional",
  "depin_grass_node_id": "optional"
}
```

The registration signature proves key ownership:

```
Kairo→YieldSwarm driver registration
kairo_user_id:{id}
evm:{address}
```

## Signed telemetry

Every GPS/speed/acceleration packet must be signed by the driver's private key.

### Canonical payload (sorted JSON → SHA-256 → EIP-191 sign)

```json
{
  "driver_id": "uuid",
  "kairo_session_id": "session-uuid",
  "recorded_at": "2026-06-15T12:00:00+00:00",
  "gps": { "latitude": 37.7749, "longitude": -122.4194 },
  "speed_mps": 12.5,
  "acceleration_mps2": 0.5,
  "heading_deg": 90.0,
  "route": null
}
```

```http
POST /api/v1/telemetry/ingest
{
  "payload": { … },
  "signature_hex": "0x…"
}
```

Response includes Mandelbrot routing:

```json
{
  "routing": {
    "shard_id": 42,
    "tree_of_life_node": "Netzach",
    "helix_path": "helix://yieldswarm/shard/42/sephira/Netzach/…",
    "yieldswarm_cron_slot": 42
  }
}
```

## Mandelbrot / Tree of Life pipeline

| Stage | Service | Output |
|-------|---------|--------|
| Fractal shard | `mandelbrot_router.py` | `shard_id` (0–119) from GPS escape time × sharding formula |
| Tree routing | `mandelbrot_router.py` | One of 10 sephirot nodes (Kether → Malkuth) |
| Helix path | `mandelbrot_router.py` | Cross-chain execution URI for YieldSwarm agents |
| Cron slot | `mandelbrot_router.py` | Maps to 120 OpenClaw harvest crons |

Sharding formula factors (from architecture): `1×3×5×11×1111×1×3×8×9×11`

## 2× driver pay logic

| Condition | Required |
|-----------|----------|
| Signed packets | ≥ 10 verified |
| Distance | ≥ 5 km |
| DePIN link | Helium **or** Grass node attached |
| Multiplier | **2.0×** base pay when all met |

Base rate: `BASE_PAY_RATE_USD_PER_KM` (default $0.05/km)

### Payment rails

| Rail | When used | Destination |
|------|-----------|-------------|
| `wise` | `WISE_BUSINESS_EMAIL` configured | Wise business account |
| `evm` | Default fallback | Driver `0x…` address |
| `iotex` | Future | Driver `io1…` address |

```http
GET  /api/v1/rewards/{driver_id}/quote
POST /api/v1/payments/settle/{driver_id}
```

Settlement creates a contribution ledger entry and payout quote (integrates with existing Wise + Chainlink Vault rails).

## API reference

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Service health |
| GET | `/dashboard` | Driver contribution UI |
| POST | `/api/v1/drivers/register` | Register client identity |
| POST | `/api/v1/drivers/generate` | Server keygen (dev only) |
| GET | `/api/v1/drivers/{id}` | Get driver |
| POST | `/api/v1/telemetry/ingest` | Ingest signed telemetry |
| GET | `/api/v1/telemetry/{id}/stats` | Driver telemetry stats |
| GET | `/api/v1/rewards/{id}/dashboard` | Full dashboard summary |
| GET | `/api/v1/rewards/{id}/quote` | 2× pay quote |
| POST | `/api/v1/payments/settle/{id}` | Create payout ledger |

## Vault integration

Store bridge secrets at `yieldswarm/kairo`:

```bash
vault kv put yieldswarm/kairo \
  api_signing_key="…" \
  bridge_webhook_secret="…" \
  wise_payout_email="your@wise.com"
```

Environment variables (from Vault or `.env`):

| Variable | Purpose |
|----------|---------|
| `WISE_BUSINESS_EMAIL` | Wise payment rail |
| `PAYOUT_WALLET_EVM` | YieldSwarm treasury (`0x9505…` default) |
| `KAIRO_API_PORT` | API port (default 8090) |

## Kairo app integration checklist

1. Generate secp256k1 keypair on device (Secure Enclave / Keychain)
2. Register via `POST /drivers/register` with registration signature
3. On each telemetry tick: build canonical payload → sign → `POST /telemetry/ingest`
4. Link DePIN nodes (Helium hotspot, Grass node) at registration for full rewards
5. Poll `GET /rewards/{id}/dashboard` or embed WebView to `/dashboard?driver_id=…`
6. Trigger settlement via `POST /payments/settle/{id}` on payout cycle

## File layout

```
kairo/
├── api/main.py              # FastAPI endpoints
├── client/cli.py            # Reference client (register + submit)
├── config.py                # Settings
├── db.py                    # SQLite persistence
├── models/schemas.py        # Pydantic models
├── services/
│   ├── identity_service.py  # EVM + IoTeX identity
│   ├── signing_service.py   # Telemetry signatures
│   ├── mandelbrot_router.py # Fractal + Tree of Life
│   ├── telemetry_pipeline.py
│   └── reward_service.py    # DePIN + 2× pay
├── dashboard/index.html     # Contribution UI
├── run.sh                   # Start API
└── requirements.txt
```

## Next steps

- Wire bridge webhooks into OpenClaw shard harvesting crons
- Persist to Neon (referenced in `revenue/nft-license-keys.js`)
- On-chain settlement via Chainlink Vault (`agents/chainlink-vault-manager.py`)
- Deploy bridge as Akash sidecar alongside AgentSwarm monolith
