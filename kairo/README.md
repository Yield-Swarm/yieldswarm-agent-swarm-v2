# Kairo — Driver-First Marketplace for YieldSwarm

Kairo turns every driver into a YieldSwarm DePIN node with:

- **Persistent cryptographic identity** (IoTeX + EVM compatible secp256k1)
- **Signed telemetry** (ECDSA over canonical JSON)
- **Mandelbrot / Tree of Life routing** into the 10,080-agent mesh
- **Payment rails** (1% customer fee, 2× driver pay, instant cashout)

## API Routes

| Route | Method | Purpose |
|-------|--------|---------|
| `/api/kairo/drivers/register` | POST | Create driver identity |
| `/api/kairo/drivers/register` | GET | List drivers |
| `/api/kairo/telemetry` | POST | Ingest signed telemetry |
| `/api/kairo/telemetry?driverId=` | GET | Contribution stats |
| `/api/kairo/earnings?driverId=&period=` | GET | Earnings breakdown |
| `/api/kairo/earnings` | POST | Rides, cashout, quotes |

## Dashboard

Visit `/kairo/dashboard` for data contribution and reward estimates.

## Python Ingest Bridge

```bash
python3 kairo/services/mandelbrot_ingest.py --event telemetry.json
python3 kairo/services/mandelbrot_ingest.py --watch http://localhost:3000
```

## Shared Infrastructure

Kairo reuses:

- `src/lib/payments/` — Square, Wise, Web3 rails
- `frontend/src/wallet/` — unified multi-chain wallet
- `vault/` — HashiCorp Vault secret injection
- `agents/odysseus_memory.py` — ChromaDB memory mesh
