# Kairo — Driver-First Marketplace + DePIN Node

Kairo turns every driver into a YieldSwarm node via cryptographic identity and
signed telemetry routed into the Mandelbrot / Tree of Life reward pipeline.

## Components

| Path | Purpose |
|------|---------|
| `kairo/identity/` | Persistent IoTeX + EVM compatible driver addresses |
| `kairo/telemetry/` | Signed driving telemetry |
| `kairo/pipeline/` | Mandelbrot scoring → Tree of Life node routing |
| `kairo/dashboard/` | Static contribution dashboard |
| `src/lib/kairo/` | TypeScript API store + identity helpers |
| `src/app/api/kairo/` | Next.js API routes |

## API

- `POST /api/kairo/drivers/register` — register driver, return identity
- `POST /api/kairo/telemetry` — ingest signed telemetry batch
- `GET /api/kairo/earnings/:driverId` — earnings breakdown
- `POST /api/kairo/trips/quote` — customer 1% platform fee quote
- `POST /api/kairo/trips/settle` — driver 2× pay + instant cashout option

## Local dev

```bash
npm run dev
open http://localhost:3000/kairo
```

Python pipeline tests:

```bash
python -m pytest tests/test_kairo_*.py -q
```
