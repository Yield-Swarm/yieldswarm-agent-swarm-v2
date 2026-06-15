# YieldSwarm Merge Strategy (Post-Consolidation)

> Last updated: June 15, 2026  
> Repo: [yieldswarm-agent-swarm-v2](https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2)  
> Active `cursor/*` branches analyzed: **76**

## Executive Summary

**`main` is the integrated monorepo** (~628 tracked files at `ca74492`). The original 18-branch merge coordination (`cursor/merge-coordination-93dd`) and subsequent god-prompt integration are already on `main`.

**Two feature branches remain to merge:**

| Priority | Branch | Files vs `main` | Action |
|----------|--------|-----------------|--------|
| 1 | `cursor/odysseus-brain-e512` | 17 | PR → `development` → `main` |
| 2 | `cursor/mega-round-integration-e512` | 22 | PR → `development` → `main` (after odysseus) |

**Environment branches** (`development`, `testnet`, `devnets`, `production`, `MAINNET`) are **5 commits behind `main`** at `060f193`. Run `./scripts/sync-environment-branches.sh` after the pending merges land.

**Do not merge wholesale:** 25+ duplicate Vault branches and 4 stale `*-597f` mega-task branches (500+ file diffs, diverged history).

---

## Safe Merge Plan into `main`

### Phase 0 — Preconditions (do once)

```bash
# Analyze current state
./scripts/analyze-cursor-branches.sh

# Enable on GitHub: branch protection on main (PR + CI required)
```

### Phase 1 — Merge pending features via `development`

```bash
git fetch origin
git checkout development
git pull origin development

# 1. Odysseus central brain (RTX 3090, memory, tools API)
git merge --no-ff origin/cursor/odysseus-brain-e512 \
  -m "feat(odysseus): central brain orchestrator on Akash RTX 3090"
# Resolve conflicts in backend/src/adapters/odysseus.js, api.js if any

# 2. Mega-round: Kairo frontend, smoke tests, sovereign fixes
git merge --no-ff origin/cursor/mega-round-integration-e512 \
  -m "feat: mega-round Kairo + sovereign wiring"
# Resolve overlaps in agents/*, backend routes

# Validate
python -m pytest tests/test_odysseus_brain.py tests/test_kairo_identity.py -q
bash scripts/smoke-test.sh

git push origin development
```

### Phase 2 — Promote `development` → `main`

```bash
# Open PR: development → main (preferred)
# Or use the helper:
bash scripts/merge-to-main.sh
```

### Phase 3 — Sync environment branches

```bash
./scripts/sync-environment-branches.sh
# Creates or fast-forwards: development, testnet, devnets, production, MAINNET
```

### Phase 4 — Close stale PRs (no merge)

```bash
# Run analysis to list branches to close
./scripts/analyze-cursor-branches.sh

# After PRs are closed on GitHub:
git fetch origin --prune
```

### Phase 5 — Optional review (development only)

| Branch | Files | Notes |
|--------|-------|-------|
| `cursor/helix-chain-activation-597f` | 144 | Parallel vault/akash infra — may conflict with existing `vault/` |

```bash
git checkout development
git merge --no-ff origin/cursor/helix-chain-activation-597f
# Review vault/ and deploy/ conflicts before promoting to testnet
```

---

## Branch Inventory (June 15, 2026)

### ✅ Already absorbed into `main` (0 commits ahead)

These branches have no unique commits vs `main`. Safe to delete remote refs after PR cleanup.

| Branch | Domain |
|--------|--------|
| `cursor/merge-coordination-93dd` | Original 18-branch integration |
| `cursor/vault-integration-1b83` | Canonical Vault |
| `cursor/unified-wallet-system-690e` | Multi-chain wallet |
| `cursor/build-payment-rails-5087` | Square/Wise/Web3 payments |
| `cursor/agents-arena-system-21fb` | Agent arena + manifests |
| `cursor/production-deploy-orchestrator-85ce` | Deploy orchestrator |
| `cursor/add-odysseus-deployments-edbd` | Odysseus Docker/SDL |
| `cursor/akash-lease-manager-f88c` | RTX 3090 lease manager |
| `cursor/arena-live-data-integration-f19d` | Live telemetry API |
| `cursor/odysseus-chromadb-memory-d634` | ChromaDB memory mesh |
| `cursor/yieldswarm-odysseus-tools-3c2a` | Odysseus MCP tools |
| `cursor/yieldswarm-akash-model-routing-9698` | Model router |
| `cursor/multicloud-fallback-infra-e3ca` | Multi-cloud Terraform |
| `cursor/great-delta-emission-router-4594` | Emission router |
| `cursor/trident-layer35-foundation-8f92` | Trident Layer-35 |
| `cursor/integrate-odysseus-1074` | LiteLLM + SearXNG stack |
| `cursor/odysseus-ui-integration-35ff` | Arena/Portal UI |
| `cursor/harden-akash-sdl-worker-ff04` | Worker hardening |
| `cursor/iteration-100-sovereign-loops-6c60` | Sovereign loops |
| `cursor/iteration-100-sovereign-core-fede` | $5M vault dashboard |
| `cursor/god-prompt-full-integration-d1cd` | Cross-component wiring |
| `cursor/god-prompt-helix-4f85` | Helix integration pass |
| `cursor/akash-codespace-jwt-4f85` | JWT workflow (on main) |
| `cursor/akash-auth-docs-4f85` | Auth docs (on main) |

### 🔜 Merge next

| Branch | Commits ahead | Key paths |
|--------|---------------|-----------|
| `cursor/odysseus-brain-e512` | 1 | `services/odysseus/brain.py`, `deploy/akash-odysseus.sdl.yml`, `docs/ODYSSEUS_BRAIN.md` |
| `cursor/mega-round-integration-e512` | 1 | `kairo/frontend/`, `scripts/smoke-test.sh`, `PRODUCTION_READINESS.md`, agent fixes |

**Merge order:** odysseus-brain first (backend overlap), then mega-round.

### 🔍 Review on `development` only

| Branch | Files | Reason |
|--------|-------|--------|
| `cursor/helix-chain-activation-597f` | 144 | Large parallel infra; vault path overlap |
| `cursor/mega-task-integration-*` | 24–34 | Partial overlaps; cherry-pick if needed |
| `cursor/mega-task-consolidation-*` | 30–37 | Partial overlaps |

### ❌ Close without merge

**Duplicate Vault (25 branches)** — work is on `main` via `vault-integration-1b83`:

```
cursor/vault-integration-{0277,08e6,0c68,0e66,115a,2473,2fad,33f5,37b1,3bd6,
  4288,4638,66f0,6964,9116,996d,a375,c09b,ce13,ceff,d9f0,dd69,ebb4,fe2d}
cursor/hashicorp-vault-integration-{1e74,69d3,9286,9c82,d1ea}
cursor/complete-vault-integration-{82c9,8887}
cursor/vault-secrets-integration-dc53
```

**Stale mega-task branches (diverged 78 commits, 500+ files):**

| Branch | Reason |
|--------|--------|
| `cursor/stripe-payment-flow-597f` | Superseded by `build-payment-rails-5087` on main |
| `cursor/domains-wiring-597f` | Superseded by `DOMAINS.md` on main |
| `cursor/akash-deploy-jwt-597f` | Superseded by JWT workflow on main |
| `cursor/god-prompt-full-system-597f` | Superseded by god-prompt integration on main |

**Superseded small branches:**

| Branch | Reason |
|--------|--------|
| `cursor/arena-akash-telemetry-f187` | 1 file — superseded by arena-live-data |
| `cursor/arena-telemetry-dashboard-c904` | 2 files — superseded |
| `cursor/greatdelta-emission-router-1068` | Duplicate of 4594 |
| `cursor/multicloud-fallback-6923` | Superseded by infra-e3ca |
| `cursor/akash-tfc-bootstrap-fc5d` | Overlaps production-deploy |
| `cursor/wire-unstoppable-domains-ffe8` | 3 files — review cherry-pick only |

---

## Environment Branch Strategy

See **`BRANCHES.md`** for the full six-branch model, promotion workflow, and per-environment config.

```
cursor/* PR → development → main
                              ↓
         development ← sync ← main
              ↓
    ┌─────────┼─────────┐
    ↓         ↓         ↓
 devnets   testnet   (parallel)
              ↓
         production
              ↓
          MAINNET
```

| Branch | Purpose | Current status |
|--------|---------|----------------|
| `main` | Integration gate | `ca74492` ✅ |
| `development` | Feature landing | `060f193` ⚠️ 5 behind |
| `testnet` | Akash staging | `060f193` ⚠️ 5 behind |
| `devnets` | DePIN devnets | `060f193` ⚠️ 5 behind |
| `production` | Pre-mainnet QA | `060f193` ⚠️ 5 behind |
| `MAINNET` | Live deploy tag | `060f193` ⚠️ 5 behind |

---

## Conflict Resolution Guide

| File / area | Resolution |
|-------------|------------|
| `backend/src/adapters/odysseus.js` | Keep odysseus-brain version (full tool adapter) |
| `backend/src/routes/api.js` | Union: telemetry routes from both branches |
| `agents/akash-optimizer.py` | Keep mega-round sovereign fixes |
| `.gitignore` | Union all patterns; ensure `.odysseus/` ignored |
| `vault/` vs helix-chain | Prefer existing `vault/` on main; cherry-pick helix deltas |

### Pre-merge secret audit

```bash
./scripts/pre-merge-audit.sh origin/cursor/odysseus-brain-e512
./scripts/secrets-audit.sh
```

---

## Agent Coordination Going Forward

1. **Branch off `development`** — never off stale `cursor/*` branches.
2. **One agent per domain** — no parallel Vault branches.
3. **Naming:** `cursor/<descriptive-name>-e512` (lowercase).
4. **PR target:** `development` first; human promotes to `main`.
5. **Weekly cleanup:** run `./scripts/analyze-cursor-branches.sh` and close absorbed branches.

---

## Post-Merge Checklist

- [ ] Merge `cursor/odysseus-brain-e512` → `development` → `main`
- [ ] Merge `cursor/mega-round-integration-e512` → `development` → `main`
- [ ] Run `./scripts/sync-environment-branches.sh`
- [ ] Enable branch protection on `main`, `production`, `MAINNET`
- [ ] Close 25+ duplicate Vault PRs
- [ ] `python -m pytest tests/` + `bash scripts/smoke-test.sh`
- [ ] Review `PRODUCTION_READINESS.md` blockers before MAINNET promotion
