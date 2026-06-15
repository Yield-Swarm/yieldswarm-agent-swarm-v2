# YieldSwarm Merge Report

> Last updated: June 15, 2026  
> `main` tip: `ca74492` — Merge secure Akash JWT Codespace workflow

## Current State

| Metric | Value |
|--------|-------|
| Tracked files on `main` | ~628 |
| `cursor/*` branches (remote) | 76 |
| Branches with unique commits vs `main` | ~30 |
| Branches safe to close | ~46 |
| Pending merges | 2 (`odysseus-brain-e512`, `mega-round-integration-e512`) |
| Environment branches behind `main` | 5 commits each |

## What Is on `main` Today

The consolidated monorepo includes work from the original 18-branch integration plus subsequent god-prompt and JWT workflow merges.

| Area | Key Paths | Source |
|------|-----------|--------|
| HashiCorp Vault | `vault/`, `SECRETS.md`, `akash/vault-agent.hcl` | vault-integration-1b83 |
| Unified Wallet | `frontend/src/wallet/` | unified-wallet-system-690e |
| Payment Rails | `src/app/payments/`, `src/lib/payments/` | build-payment-rails-5087 |
| Agent Arena | `agents/system/`, deity manifests | agents-arena-system-21fb |
| Deploy Orchestrator | `Makefile`, `deploy.sh`, `DEPLOY.md` | production-deploy-orchestrator-85ce |
| Odysseus Deploy | `deploy/akash-odysseus.sdl.yml`, Docker | add-odysseus-deployments-edbd |
| Sovereign Loops | `iteration-100/`, agent runners | iteration-100-sovereign-* |
| Akash Lease Manager | `akash/lease-manager.py` | akash-lease-manager-f88c |
| Live Telemetry API | `backend/src/adapters/`, routes | arena-live-data-integration-f19d |
| Odysseus Memory | `agents/odysseus_memory.py` | odysseus-chromadb-memory-d634 |
| Model Router | `services/yieldswarm_model_router.py` | yieldswarm-akash-model-routing-9698 |
| Multi-Cloud | `infra/terraform/`, `infra/packer/` | multicloud-fallback-infra-e3ca |
| Emission Router | `contracts/GreatDeltaEmissionRouter.sol` | great-delta-emission-router-4594 |
| Trident Layer-35 | `contracts/quadrant-iv/` | trident-layer35-foundation-8f92 |
| Kairo scaffold | `kairo/` | mega-round (partial — see pending) |
| JWT Codespace | `scripts/akash-jwt-*.sh`, auth docs | akash-codespace-jwt-4f85 |
| God Prompt wiring | cross-component API fixes | god-prompt-full-integration-d1cd |

## Pending Merges

### 1. `cursor/odysseus-brain-e512` (priority)

Central orchestration layer: memory recall, model routing, YieldSwarm tools, RTX 3090 Akash SDL with Ollama sidecar.

| Path | Change |
|------|--------|
| `services/odysseus/brain.py` | `OdysseusBrain` orchestrator |
| `services/odysseus/main.py` | HTTP API (`/healthz`, `/api/tools/execute`, `/api/memory/recall`) |
| `deploy/akash-odysseus.sdl.yml` | Ollama + brain + sync services |
| `backend/src/routes/tools.js` | Tool execution proxy |
| `docs/ODYSSEUS_BRAIN.md` | Deploy and architecture docs |
| `tests/test_odysseus_brain.py` | Unit tests (passing) |

### 2. `cursor/mega-round-integration-e512`

Kairo frontend deploy, smoke tests, sovereign agent fixes, production readiness docs.

| Path | Change |
|------|--------|
| `kairo/frontend/index.html` | Contribution dashboard |
| `scripts/smoke-test.sh` | Integration smoke suite |
| `PRODUCTION_READINESS.md` | Pre-mainnet blockers |
| `agents/_bootstrap.py` | Import path fix |
| `deploy/runtime/swarm_runner.py` | Sovereign cycle dedup |

## Safe Merge Sequence

```
1. cursor/odysseus-brain-e512  →  development  →  main
2. cursor/mega-round-integration-e512  →  development  →  main
3. ./scripts/sync-environment-branches.sh
4. Promote: development → testnet → production → MAINNET (per BRANCHES.md)
5. Close 46 absorbed/duplicate cursor/* PRs
```

## Branches to Close (No Merge)

- **25 Vault duplicates** — canonical work on main
- **4 stale `*-597f` branches** — 500+ file diffs, superseded content
- **5 superseded small branches** — arena telemetry, greatdelta duplicate, multicloud-6923, akash-tfc, wire-domains

Run `./scripts/analyze-cursor-branches.sh` for the live categorized list.

## Technical Debt (unchanged)

| Issue | Severity | Action |
|-------|----------|--------|
| Duplicate GreatDelta router (`contracts/` vs `contracts/quadrant-iv/`) | Medium | Consolidate before MAINNET |
| React vs static Arena frontends | Medium | Wire React Arena to backend API |
| Two Terraform roots (`terraform/` vs `infra/terraform/`) | Low | Document per-environment choice |
| Auth stubs in `backend/src/routes/api.js` | Medium | Wire Vault OIDC before production |
| `dashboard/state.json` seed data (9k+ lines) | Low | Move to generated artifact |

## Deployment Readiness

| Component | Ready? | Notes |
|-----------|--------|-------|
| Vault bootstrap | ✅ | `vault/setup/bootstrap.sh` |
| Odysseus brain | 🔜 | Merge odysseus-brain-e512 first |
| Akash RTX 3090 deploy | 🔜 | SDL ready after brain merge |
| Frontend wallet | ⚠️ | `npm install && npm run build` |
| Payment rails | ⚠️ | Sandbox keys in Vault |
| Sovereign loops | ⚠️ | Wire to live feeds on testnet |
| MAINNET | ❌ | See `PRODUCTION_READINESS.md` |

## Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/analyze-cursor-branches.sh` | Categorize all cursor/* branches |
| `./scripts/sync-environment-branches.sh` | Align env branches to main |
| `./scripts/merge-swarm.sh` | Coordinator (analyze + optional sync) |
| `./scripts/merge-to-main.sh` | Promote development → main |

## Documentation

- **`BRANCHES.md`** — six-branch environment model and promotion workflow
- **`MERGE_STRATEGY.md`** — safe merge plan and branch inventory
- **`PRODUCTION_READINESS.md`** — MAINNET blockers
- **`docs/ODYSSEUS_BRAIN.md`** — brain architecture (after merge)
