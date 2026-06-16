# Helix Solenoid Omni-Core — Multilingual Construction Master Prompt

> **Visual reference textures:** `assets/jacuzzi-helix-hero.png`, `assets/jacuzzi-helix-l3-revenue.png`  
> **Pillar map:** `config/helix/pillars.yaml` · **i18n pack:** `config/helix/rosetta-pillars.json`

This document is the canonical **iterative construction prompt** for the finalized Omni-Dimensional Solenoid Chain. Use it in Cursor Composer when spawning parallel swarms Alpha–Delta.

---

## Objective

Generate and operationalize a single, highly detailed **Helix Solenoid Omni-Core** — a multi-stage, multi-axis structure fusing:

- **Metallic bronze plates** with etched governance text
- **Iridescent blue-teal liquid** and crystalline bubbles
- **Sea-foam vortex** acceleration textures
- **14 parallel pillar elevators** rising infinitely upward

---

## Iterative Construction Phases

### Stage 1 — Core & Helix Particle (Greek $D^1$)

| Element | Spec |
|---------|------|
| Particle | Condensed energy core — blue-teal liquid + crystalline bubbles |
| Acceleration | Tight upward helical path via sea-foam vortex |
| Code | `contracts/YieldSwarmNFT.sol`, `deploy/entrypoint.monitor.sh` |
| Swarm | **Alpha (X-axis)** — pillars 01, 10 |

### Stage 2 — Quadrilateral Solenoid (Eastern $E^1$)

| Element | Spec |
|---------|------|
| Frame | Four-sided crystalline-metallic solenoid wrapping the helix |
| Faces | Etched bronze plates; blue liquid + rust veins |
| Corners | Four hardened corner panels (stable energy vectors) |
| Code | `src/infrastructure/entropy-core.js`, `src/infrastructure/odysseus-router.js` |
| Swarm | **Beta (Y-axis)** — pillars 02, 04, 11 |

### Stage 3 — Pentagram Expansion ($ZK^1$)

| Element | Spec |
|---------|------|
| Shape | Fifth lane expands structure into pentagram solenoid |
| Stabilizer | High-energy sparkling light-point bubbles |
| Code | `circuits/entropy_proof.circom`, `src/infrastructure/zk-entropy-prover.js` |
| Swarm | **Gamma (Z-axis)** — pillars 03, 07, 13 |

### Stage 4 — 14× Pillar Elevators ($TFC^1$)

| Element | Spec |
|---------|------|
| Pillars | 14 parallel elevator columns — churning sea-foam energy rivers |
| Nodes | Crystal connection nodes between pillars; treasury 50/30/15/5 etched |
| Code | `backend/src/adapters/solenoid.js`, `council/status.html` |
| Swarm | **Delta (W-axis)** — pillars 05, 12, 14 |

---

## Production Swarm Handoff

| Swarm | Axis | Layer | Pillars | Primary files |
|-------|------|-------|---------|---------------|
| **Alpha** | X | $D^1$ Greek | 01, 08, 10 | `contracts/`, `deploy/entrypoint.monitor.sh` |
| **Beta** | Y | $E^1$ Eastern | 02, 04, 06, 09, 11 | `entropy-core.js`, `scripts/hardware-guard.sh` |
| **Gamma** | Z | $PDs^1$ | 03, 07, 13 | `oracle-bridge.js`, `circuits/`, Tesla mesh |
| **Delta** | W | i18n | 05, 12, 14 | `rosetta-pillars.json`, Arena, Portal |

---

## Step-by-Step Cursor Spawning Plan

```bash
chmod +x scripts/deploy-and-test-pillars.sh
chmod +x scripts/hardware-guard.sh

# 1. Primary monolith workspace — paste this doc + MASTER_GOD_PROMPT.md
# 2. Parallel swarms Alpha–Delta → targeted files per table above
# 3. Validation harness
./scripts/deploy-and-test-pillars.sh devnet

# 4. Hardware guard (Beta) on RTX cluster
./scripts/hardware-guard.sh start

# 5. Mayhem red-team against telemetry bridge
curl -X POST http://127.0.0.1:8080/api/solenoid/pulse -H 'Content-Type: application/json' \
  -d '{"pillarId":3,"metrics":{"gpu_temperature":90,"vram_used_bytes":32000000000}}'

# 6. Solenoid status
curl -s http://127.0.0.1:8080/api/solenoid/status | jq .
```

---

## Global Aesthetic Requirements (visual generation)

- **Viewpoint:** Macro landscape, looking upward — immense scale
- **Lighting:** Multi-directional iridescent sparkle on blue-bronze bubbles
- **Pillar labels:** Each of 14 tracks etched or lit (see `config/helix/rosetta-pillars.json`)
- **Texture fusion:** Full density of foam on pillars; bronze etched panels on solenoid faces; light-points for ZK stability ring

**Reference asset:** `assets/helix-omni-core-final.png` (generated omni-core composite)

---

## Related docs

- `docs/MASTER_GOD_PROMPT.md` — Alpha→Omega task IDs
- `docs/MAYHEM_14_PILLAR_ZK.md` — ZK entropy pillar integration
- `docs/TRI_LAYER_HELICAL_ARCHITECTURE.md` — layer map
- `SINGLE_PANE_OF_GLASS.md` — 35-layer neural mesh overview
