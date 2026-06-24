# Geominer / Swarmer Checklists — COIN-style onboarding

> **Audience:** DePIN geominers, YieldSwarm node operators, ethyswarm@proton.me profile sync  
> **API:** `POST /api/sync` · `GET /api/depin/checklist` · `POST /api/depin/checklist`

---

## Sourcing Intro Checklist — unlock the swarm

Complete all three steps to unlock the **Yield Dashboard**, automatic reward claims, and a Genesis geodrop prize.

| Step | ID | Action |
|------|-----|--------|
| 1 | `gateway_subnet` | Lock local gateway to primary Verizon 5G subnet (`192.168.1.1`). Forget rogue neighbor APs (e.g. Shark vacuum hotspots). |
| 2 | `ioid_register` | Register IoTeX Pebble / router via W3bstream (`IOTEX_DEVICE_ID`). See `docs/IOTEX_W3BSTREAM_INTEGRATION.md`. |
| 3 | `pour_over_sim` | Run a **Pour Over** short workload (3 compute scoops / 10 fl oz context) to verify telemetry parses on-chain. |

**Mark complete:**

```bash
curl -X POST https://yieldswarm-agent-swarm-v2-mainnet.onrender.com/api/depin/checklist \
  -H 'Content-Type: application/json' \
  -d '{"email":"you@example.com","phase":"intro","taskId":"gateway_subnet"}'
```

---

## Daily Brew Checklist — maximize compute yield

Complete all four tasks daily (UTC). Six consecutive days unlocks a **STREAK** multiplier.

| Task | ID | Action |
|------|-----|--------|
| 1 | `heartbeat` | Verify ElizaOS agent cohorts maintain 420s heartbeat |
| 2 | `atomic_pulse` | Run ATOMIC_PULSE self-audit (every 1h 33m) |
| 3 | `yslr_scan` | YSLR scanner on HELIX blocks 1–128,000 (15m poll) |
| 4 | `venti_workload` | Execute Venti workload (5 scoops / 24 fl oz data) |

**Streak multiplier:**

\[
M_{\text{streak}} = 1.0 + 0.5 \cdot \ln(1 + D_{\text{completed}})
\]

Where \(D_{\text{completed}}\) is consecutive daily completions (capped at 6).

---

## Sync your COIN / geomining profile

```bash
curl -X POST https://yieldswarm-agent-swarm-v2-mainnet.onrender.com/api/sync \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "ethyswarm@proton.me",
    "plan": "Lite",
    "currentBalance": 1000.00,
    "geomines": 0,
    "geodrops": 0,
    "surveys": 0,
    "spentGeoclaims": 0.0,
    "spentGeodrops": 0.0,
    "spentSweepstakes": 0.0
  }'
```

---

## Support

- Email: support@yieldswarmofficial.xyz  
- Health: `GET /healthz`  
- Consensus smoke: `GET /api/depin/consensus?rounds=100`
