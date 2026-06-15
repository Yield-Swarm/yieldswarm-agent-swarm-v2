# MERGE_STRATEGY.md — YieldSwarm Repository Consolidation

> **Last updated:** June 15, 2026  
> **Repo:** [yieldswarm-agent-swarm-v2](https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2)  
> **`main` tip:** `12efeee` — integrated monorepo (~700+ files)  
> **Active `cursor/*` branches:** 82

---

## Executive Summary

`main` is the **canonical integration branch**. The original 18-branch merge coordination, god-prompt integration, Odysseus brain, Stripe payments, model router, and Vault stack are already merged.

**This pass adds:**
- Bittensor dual-purpose miner layer (cherry-picked from `cursor/bittensor-miner-acceleration-9c82`, adapted to `vault/` layout)
- Kairo identity test fix (`pycryptodome` in `kairo/requirements.txt`)
- Vault path alignment for `runtime/bittensor`
- Environment branch sync to `main`

**Do not wholesale-merge** any `cursor/*` branch with 70+ commits behind `main` — cherry-pick deltas only.

---

## Branch Topology

```
cursor/* feature PR
        ↓
   development          ← daily agent landing zone
        ↓
       main             ← integration gate (PR + CI)
        ↓
  ┌─────┼─────┬─────────┐
  ↓     ↓     ↓         ↓
devnets testnet production MAINNET
```

| Branch | Purpose | Protection |
|--------|---------|------------|
| `main` | Clean integration snapshot | Required PR + CI |
| `development` | Active feature work | Optional |
| `testnet` | Akash staging + Vercel preview | Smoke tests |
| `devnets` | DePIN devnets (IoTeX, HNT, GRASS) | Smoke tests |
| `production` | Pre-mainnet QA | Required reviews |
| `MAINNET` | Live deploy tag | Required reviews |

See **`BRANCHES.md`** for promotion workflow and per-environment Vault namespaces.

---

## Safe Merge Plan

### Phase 0 — Preconditions

```bash
git fetch origin --prune
./scripts/analyze-cursor-branches.sh
./scripts/secrets-audit.sh
python3 -m pytest tests/ -q
```

### Phase 1 — Land integration pass on `development`

```bash
git checkout development
git pull origin development
git merge --no-ff origin/cursor/merge-integration-pass-9c82 \
  -m "feat: Bittensor layer + merge coordination integration pass"
git push origin development
```

### Phase 2 — Promote `development` → `main`

```bash
# Preferred: open PR development → main
bash scripts/merge-to-main.sh
# Or: merge PR on GitHub after CI green
```

### Phase 3 — Sync environment branches

```bash
./scripts/sync-environment-branches.sh
```

This fast-forwards `development`, `testnet`, `devnets`, `production`, and `MAINNET` to `main` when they have zero unique commits.

### Phase 4 — Close absorbed branches (no merge)

Run `./scripts/analyze-cursor-branches.sh` and close all branches in the **ALREADY ON main** and **CLOSE without merge** sections on GitHub.

---

## Branch Inventory (June 15, 2026)

### ✅ Already absorbed into `main` (0 commits ahead)

| Branch | Domain |
|--------|--------|
| `cursor/merge-coordination-93dd` | Original 18-branch integration |
| `cursor/god-prompt-full-integration-d1cd` | Cross-component wiring |
| `cursor/odysseus-brain-e512` | Central brain orchestrator |
| `cursor/mega-round-integration-e512` | Kairo frontend + smoke tests |
| `cursor/vault-integration-1b83` | Canonical Vault (`vault/`) |
| `cursor/akash-codespace-jwt-4f85` | JWT Codespace workflow |
| `cursor/build-payment-rails-5087` | Payment rails |
| `cursor/agents-arena-system-21fb` | Agent arena |
| `cursor/integrate-odysseus-1074` | LiteLLM + SearXNG |
| `cursor/iteration-100-sovereign-*` | Sovereign loops |
| *(+17 more — see analyze script output)* | |

### 🔜 Cherry-pick only (do NOT wholesale merge)

| Branch | Unique delta | Action |
|--------|--------------|--------|
| `cursor/bittensor-miner-acceleration-9c82` | Bittensor miner + SDL | **Cherry-picked** in `merge-integration-pass-9c82` |
| `cursor/kairo-yieldswarm-bridge-9c82` | Bridge docs + emitter | Review vs `kairo/` on main; cherry-pick `yieldswarm_emitter` if missing |
| `cursor/env-vars-catalog-597f` | Env catalog | Review → merge to `development` if not duplicated |
| `cursor/odysseus-model-router-d1cd` | Model router | **Already on main** (`12efeee`) |

### 🔍 Review on `development` only

| Branch | Files | Notes |
|--------|-------|-------|
| `cursor/helix-chain-activation-597f` | 144 | Parallel infra; conflicts with `vault/` |
| `cursor/great-delta-integration-4f85` | 22 | Contract deploy deltas |
| `cursor/mega-task-consolidation-f9c3` | 30 | Partial overlaps |
| `cursor/akash-tfc-bootstrap-fc5d` | 17 | TFC bootstrap |

### ❌ Close without merge (40+ branches)

**Duplicate Vault (25+ branches)** — canonical path is `vault/` via `vault-integration-1b83`:

```
cursor/vault-integration-{0277..fe2d}  (25 branches)
cursor/hashicorp-vault-integration-{1e74,69d3,9286,9c82,d1ea}
cursor/complete-vault-integration-{82c9,8887}
cursor/vault-secrets-integration-dc53
```

**Stale mega-task (diverged 85+ commits, 500+ files):**

| Branch | Reason |
|--------|--------|
| `cursor/stripe-payment-flow-597f` | Superseded — Stripe on `main` |
| `cursor/domains-wiring-597f` | Superseded — `DOMAINS.md` on main |
| `cursor/akash-deploy-jwt-597f` | Superseded — JWT on main |
| `cursor/god-prompt-full-system-597f` | Superseded |

**Superseded small branches:**

| Branch | Reason |
|--------|--------|
| `cursor/arena-akash-telemetry-f187` | Superseded by arena-live-data |
| `cursor/arena-telemetry-dashboard-c904` | Superseded |
| `cursor/wire-unstoppable-domains-ffe8` | Cherry-pick only if UD records missing |

---

## Conflict Resolution Guide

| Area | Resolution |
|------|------------|
| `vault/` vs `infra/vault/` | **Keep `vault/`** on main; never merge `infra/vault/` branches |
| `kairo/` duplicate trees | Keep main's `kairo/`; cherry-pick unique services only |
| `deploy/akash/entrypoint.sh` vs `scripts/deploy-to-akash.sh` | Use `scripts/deploy-to-akash.sh` (canonical) |
| `PRODUCTION_READINESS.md` | Union checklists; remove duplicate sections |
| `.gitignore` | Union all patterns; ensure `.run/`, `.odysseus/`, `bin/` ignored |

### Pre-merge secret audit

```bash
./scripts/pre-merge-audit.sh origin/cursor/<branch>
./scripts/secrets-audit.sh
```

---

## Vault Canonical Paths

All secrets route through HashiCorp Vault KV v2 mount `yieldswarm/`:

| Path | Consumer |
|------|----------|
| `runtime/core` | Agent master keys |
| `runtime/llm` | OpenAI, Anthropic, Grok |
| `runtime/wallets` | Encryption + signing keys |
| `runtime/akash` | Akash wallet + JWT |
| `runtime/odysseus` | Brain API + model host |
| `runtime/kairo` | Mapbox, IoTeX, identity |
| `runtime/payments` | Stripe, Square, Wise |
| `runtime/bittensor` | Miner wallet, netuid, model |
| `rpc/bittensor` | Staking node key |
| `providers/*` | Terraform cloud creds |

Bootstrap: `vault/scripts/bootstrap.sh` + `vault/scripts/seed-secrets.sh`

---

## Agent Coordination Rules

1. **Branch off `development`** — never off stale `cursor/*` branches
2. **One agent per domain** — no parallel Vault branches
3. **Naming:** `cursor/<descriptive-name>-9c82` (lowercase)
4. **PR target:** `development` first; human promotes to `main`
5. **Weekly:** run `./scripts/analyze-cursor-branches.sh` and close absorbed branches

---

## Post-Merge Checklist

- [x] Bittensor layer integrated (cherry-pick, not wholesale merge)
- [x] Kairo identity tests passing
- [x] Vault `runtime/bittensor` path + policy added
- [ ] Merge `cursor/merge-integration-pass-9c82` → `development` → `main`
- [ ] Run `./scripts/sync-environment-branches.sh`
- [ ] Enable branch protection on `main`, `production`, `MAINNET`
- [ ] Close 40+ duplicate/stale `cursor/*` PRs
- [ ] `python3 -m pytest tests/` + `bash scripts/smoke-test.sh`
- [ ] Review `PRODUCTION_READINESS.md` blockers before MAINNET
