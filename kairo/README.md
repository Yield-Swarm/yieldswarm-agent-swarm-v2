# Kairo — Cryptographic Identity + Ride/Delivery App

Kairo is the consumer app integrated with YieldSwarm's DePIN intelligence layer.

## Quick start

```bash
pip install -r kairo/requirements.txt
python -m kairo.api.main          # API on :8787
python -m http.server 5173 -d kairo/frontend  # UI
```

## Docs

- `KAIRO_FRONTEND.md` — deployment, Mapbox, Vercel/Netlify
- `DOMAINS.md` — `kairo.x`, `kairo.crypto` DNS records
- `INTEGRATION_REPORT.md` — full system wiring

## Architecture

```
kairo/
├── models/identity.py    # IoTeX + EVM driver identity
├── models/telemetry.py   # Signed GPS telemetry
├── services/pipeline.py  # Mandelbrot / Tree of Life routing
├── services/rewards.py   # 1% fee, 2× pay, DePIN breakdown
├── api/main.py           # HTTP API
├── frontend/index.html   # Mapbox ride/delivery UI
└── tests/                # pytest suite
```

Telemetry flows: **Kairo → Mandelbrot shards → Odysseus memory → 10,080 agents**
