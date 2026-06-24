# Cursor God Task — Helix Omni Monolith (Quadrilateral → Pentagram → 14× Elevators)

**Repo:** `yieldswarm-agent-swarm-v2`  
**Stack:** Pure Cursor + Node backend `:8080` + Next.js — **no Polsia**  
**Credits:** $5,408 across Akash, Azure, GCP, AWS, Alibaba, Vast, RunPod, Cherry, Salad, HashiCorp  

ChainNexus concepts map to **Nexus Chain** (`/api/nexus/*`) — not a separate codebase.

---

## Tri-Solenoid + Chains

| Solenoid | Chain | API | Config |
|----------|-------|-----|--------|
| 1 Nexus | Orchestration / Apollo Nexus Engine | `/api/nexus/*` | `config/nexus/solenoids.yaml` |
| 2 Helix | Cross-chain yield / YSLR World | `/api/helix/*` | `onchain/programs/helix/` |
| 3 Shadow | Arena competition | `/api/shadow/*` | `contracts/solenoid/Shadow.sol` |

---

## Dimensional build stages

```
1D Particilizer   → sanitize inputs, SHA-256 state anchors
2D Quadrilateral  → 4-corner solenoid (current: QuadrilateralSolenoidRouter)
3D Pentagram      → +5th lane (shift via solenoid engine / ZK mayhem)
4D 14× Elevators  → parallel pillars + neural mesh
```

**Textures (visual spec):** `config/helix/pillars.yaml` stages S1–S4

---

## One-command Phase 1 validation

```bash
npm run prod:backend          # :8080
npm run helix:deploy-pillars  # 14-pillar Mayhem pulse
curl -s http://127.0.0.1:8080/api/neural-mesh/status | jq
curl -s http://127.0.0.1:8080/api/solenoid/status | jq
```

---

## MASTER GOD PROMPT (paste into Cursor Composer — attach `.cursorrules`, `config/helix/pillars.yaml`, `backend/src/server.js`)

```markdown
@workspace MASTER GOD TASK — Helix Omni Monolith v5

You are Lead Architect for YieldSwarm. Build along 4 axes:
- X (D¹): zero-trust isolation, VRAM 29.5GB cap, thermal 83°C — deploy/entrypoint.monitor.sh
- Y (E¹): multilingual PoW, telemetry, workload shed — src/infrastructure/entropy-core.js
- Z (PDs¹): Tesla Fleet + Starlink + ZK mutation — POST /api/telemetry/tesla, circuits/entropy_proof.circom
- W (i18n): RosettaStoneLanguageCore in entropy-core.js

CURRENT REPO PATHS (use exactly):
- Quadrilateral router: src/infrastructure/odysseus-router.js (QuadrilateralSolenoidRouter)
- Entropy: src/infrastructure/entropy-core.js (MultiLingualSolenoidEngine, TeslaMeshEntropyCore, HardenedAuditEngine)
- Oracle bridge: src/infrastructure/oracle-bridge.js (TelemetryValidationBridge)
- Backend bridge: backend/src/adapters/solenoid.js
- 14 pillars: config/helix/pillars.yaml
- Deploy harness: scripts/deploy-and-test-pillars.sh
- Neural mesh: services/neural_mesh/elevators.py, config/neural_mesh/external_apis.yaml
- Tri-solenoid: config/nexus/solenoids.yaml

OBJECTIVES (priority order):
1. Harden contracts: YieldSwarmNFT, MutationController, MultiSplitLeasing, TokenStakingPool
2. Sovereign Optimizer v6 — src/infrastructure/sovereign-optimizer.js + services/sovereign_optimizer_v6.py
3. Odysseus strict tokenId isolation — do NOT confuse with backend/src/infrastructure/odysseus-router.js (GPU inference)
4. dYdX v4 bridge — backend/src/infrastructure/dydx-bridge.js
5. vLLM RTX 5090 — deploy/akash-rtx5090-vllm.sdl.yml, deploy/Dockerfile.bert, deploy/entrypoint.bert.sh
6. Chainlink Functions — functions/mutate-agent.js + backend oracle-bridge
7. Wire remaining APIs in config/neural_mesh/external_apis.yaml toward 88 targets

RULES: Production code only. Map every change to pillar id 1–14. Run npm run test:helix before commit.

BEGIN.
```

---

## Parallel swarm tracks (4 Cursor sessions — no overlap)

### Track Alpha — X-axis D¹ (Pillars 1, 10)

```
Reference MASTER GOD TASK. Pillars 1 + 10.
- Harden contracts/YieldSwarmNFT.sol, contracts/agent-nft/, vault policies
- Verify deploy/entrypoint.monitor.sh thermal 83°C + VRAM 31677329408
- Enforce tenant sanitization in QuadrilateralSolenoidRouter.processAxisMatrix
Files: contracts/, deploy/entrypoint.monitor.sh, vault/policies/
```

### Track Beta — Y-axis E¹ (Pillars 2, 4, 11)

```
Reference MASTER GOD TASK. Pillars 2, 4, 11.
- Extend MultiLingualSolenoidEngine difficulty from telemetry
- Wire deploy/akash-rtx5090-vllm.sdl.yml continuous batching + AWQ
- Connect /api/telemetry/pulse to HardenedAuditEngine state chain
Files: src/infrastructure/entropy-core.js, deploy/akash-rtx5090-vllm.sdl.yml, backend/src/adapters/rtx5090Telemetry.js
```

### Track Gamma — Z-axis PDs¹ (Pillars 3, 7, 13)

```
Reference MASTER GOD TASK. Pillars 3, 7, 13.
- ZK: circuits/entropy_proof.circom → MutationController weekly mutation
- Tesla: POST /api/telemetry/tesla via TeslaMeshEntropyCore (live keys: TESLA_CLIENT_ID)
- Starlink: backend/src/adapters/starlink.js — implement live fetch when STARLINK_API_KEY set
- Treasury: sovereign-optimizer ranks routes using $5408 credit pool
Files: circuits/, backend/src/adapters/teslaFleet.js, src/infrastructure/sovereign-optimizer.js
```

### Track Delta — W-axis i18n (Pillars 5, 12, 14)

```
Reference MASTER GOD TASK. Pillars 5, 12, 14.
- Expand RosettaStoneLanguageCore to 14 locales — config/helix/rosetta-pillars.json
- Arena + governance UI strings via /api/solenoid/matrix targetLocale param
- Valhalla portal: frontend/src/routes/Portal
Files: config/helix/rosetta-pillars.json, frontend/, council/
```

---

## Solenoid 3 + Pentagram + Neural Mesh prompt

```markdown
@workspace SOLENOID EXPANSION TASK

Implement pentagram mode in QuadrilateralSolenoidRouter:
1. After 4-corner matrix pass, add 5th lane (ZK + Tesla resonance) — increment MultiLingualSolenoidEngine to pentagram
2. Expose POST /api/solenoid/shift { "mode": "PENTAGRAM" | "14X_ELEVATORS" }
3. Wire services/neural_mesh/elevators.py to POST /api/neural-mesh/matrix with exactly 14 payloads
4. Register new APIs in config/neural_mesh/external_apis.yaml (target 88)

Physical mesh ingest:
- Tesla fleet → POST /api/telemetry/tesla { vin, telemetry_data: { battery_level, grid_frequency } }
- Starlink → GET /api/neural-mesh/starlink/:terminalId
- Vehicle DePIN → POST /api/iot/telemetry

Test: npm run helix:deploy-pillars && curl /api/neural-mesh/status
```

---

## ChainNexus → Helix absorption map

| ChainNexus concept | YieldSwarm equivalent |
|--------------------|----------------------|
| Pool cache / yield history | `backend` mining + helix adapters |
| Redis rate limit | `backend/src/lib/cache.js` + Akash telemetry |
| SSE stream | `/api/sovereign/stream`, `/api/single-pane/overview` |
| API keys | Vault `yieldswarm/runtime/*` |
| Optimizer | `/api/great-delta/overview` + sovereign-optimizer |
| Auth JWT | Vault + integration server (extend as needed) |

Do **not** import Polsia. Extend existing `backend/src/routes/api.js` patterns.

---

## API endpoints (new / key)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/neural-mesh/status` | Tri-solenoid + mesh overview |
| POST | `/api/neural-mesh/matrix` | 14-lane matrix |
| POST | `/api/telemetry/tesla` | Tesla Fleet ingest |
| GET | `/api/neural-mesh/starlink` | Starlink status |
| POST | `/api/solenoid/matrix` | Full quadrilateral run |
| POST | `/api/solenoid/pulse` | Pillar Mayhem validation |

---

## Environment secrets

```bash
# Tesla (pillar 7)
TESLA_CLIENT_ID=
TESLA_CLIENT_SECRET=
TESLA_DOMAIN=

# Starlink (pillar 7 extension)
STARLINK_API_KEY=

# Tri-chain
NEXUS_CHAIN_URL=
HELIX_CHAIN_URL=
SHADOW_CHAIN_URL=

# Credits burst
AKASH_WALLET_MNEMONIC=
AZURE_SUBSCRIPTION_ID=
```

---

## Expansion roadmap

| Phase | Target | Gate |
|-------|--------|------|
| 1 | 14 pillars locked | `helix:deploy-pillars` green |
| 2 | 420 agent pillars | ZK Mayhem pass per pillar |
| 3 | 917 mesh | Governance + SOL bounty program |

Realistic mining/cloud ROI: 12–24 months at $0.115/kWh — use credits for **burst testing**, not guaranteed 90-day 5×.

---

## Image / visual construction prompt (Cursor image gen or design handoff)

See `docs/HELIX_OMNI_CORE_CONSTRUCTION.md` — stages S1→S4 with texture refs image_0–image_4.

---

*Generated for Cursor swarm handoff — branch `cursor/helix-omni-god-task-597f`*
