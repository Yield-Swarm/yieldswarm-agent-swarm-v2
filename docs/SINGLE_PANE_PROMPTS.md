# YieldSwarm — Single Pane of Glass (All 20 Prompts)

Master operator view wiring all integration prompts into one API surface.

## Live surfaces

| Pane | URL |
|------|-----|
| **Command Center (TV)** | `/command-center` or `/tv` |
| **Arena aggregate** | `GET /api/arena/overview` |
| **Single Pane full** | `GET /api/single-pane/overview` |
| **Prompt status** | `GET /api/single-pane/prompts` |
| **TV dashboard data** | `GET /api/tv/dashboard` |
| **IoT devices** | `GET /api/iot/devices` |
| **Neural mesh viz** | `/dashboard/neural-mesh-viz.html` |

## Prompt map

| # | Title | Module |
|---|-------|--------|
| 1 | Node 5 Stellar + Cosmos | `nodes/node5/` |
| 2 | Unified mining manager | `mining/` |
| 3 | IoT device registry | `services/iot/` |
| 4 | Command center TV dashboard | `dashboard/command-center.html` |
| 5 | Tesla Fleet + Dojo | `src/infrastructure/entropy-core.js` |
| 6 | YSLR encrypted queue | `services/yslr/queue.py` |
| 7 | Neural mesh 14 elevators | `services/neural_mesh/` |
| 8 | Universal Time Coordinate | `services/utc/scheduler.py` |
| 9 | Aquarius schedule engine | `services/astro_schedule/` |
| 10 | Multi-chain SDKs | `services/cross_chain/` |
| 11 | Helix A+1 sharding | `services/helix/sharding.py` |
| 12 | Agent deploy OAuth2 | `services/agent_deploy/oauth.py` |
| 13 | Mainnet 12+ operators | `config/mainnet/operators.json` |
| 14 | Vercel/Render + Neon | `vercel.json`, `services/neon_store.py` |
| 15 | Frequency visualizer | `dashboard/neural-mesh-viz.html` |
| 16 | Multi-screen TV sync | `services/iot/sync_hub.py` |
| 17 | Jack 3% profit share | `services/business/profit_share.py` |
| 18 | Magic links (team) | `services/business/magic_links.py` |
| 19 | Dune Analytics | `services/integrations/dune.py` |
| 20 | QuickBooks payroll | `services/integrations/quickbooks.py` |

## Quick start

```bash
# Bootstrap IoT from env
export DEPIN_HELIUM_HOTSPOT_KEYS='[{"serial":"60013006881","ssid":"Helium-5G-141C"}]'

# Start integration server
cd backend && npm start

# Open TV command center
open http://127.0.0.1:8080/command-center

# Full single pane snapshot
curl -s http://127.0.0.1:8080/api/single-pane/overview | jq '.data.prompts'
```

## Environment

See `.env.example` for:
- `IOT_APPLE_TV_HOSTS`, `IOT_FIRE_TV_HOSTS`
- `JACK_PROFIT_WALLET`, `MAGIC_LINK_*_EMAIL`
- `DUNE_API_KEY`, `QUICKBOOKS_*`
- `OPERATOR_*_RPC` for mainnet operators
