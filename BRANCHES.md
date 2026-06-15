# BRANCHES.md — YieldSwarm Branch Structure

> Last updated: June 15, 2026  
> Repo: [yieldswarm-agent-swarm-v2](https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2)

## Overview

YieldSwarm uses a **six-branch environment model**. All feature work lands on `development` first; changes promote through increasingly hardened environments toward `MAINNET`.

```
                    ┌─────────────┐
                    │    main     │  ← integration gate (PR + checks)
                    └──────┬──────┘
                           │ merge / fast-forward
                    ┌──────▼──────┐
              ┌─────┤ development ├─────┐
              │     └──────┬──────┘     │
              │            │            │
       ┌──────▼──────┐     │     ┌──────▼──────┐
       │   devnets   │     │     │   testnet   │
       │ IoTeX/HNT/  │     │     │ Akash stage │
       │   GRASS     │     │     │ Vercel prev │
       └─────────────┘     │     └──────┬──────┘
                           │            │
                    ┌──────▼──────┐     │
                    │ production  │◄────┘
                    │ pre-mainnet │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   MAINNET   │
                    │  live deploy│
                    └─────────────┘
```

---

## Branch definitions

| Branch | Purpose | Who pushes | Protection | Deploy target |
|--------|---------|------------|------------|---------------|
| `main` | Clean integration snapshot; source of truth for releases | Merge PRs only | **Required** — reviews + CI | Reference only |
| `development` | Active daily development; all `cursor/*` PRs target here | Agents + humans | Optional | Local / Codespaces |
| `testnet` | Staging: Akash testnet, Vercel preview, payment sandbox | Promotion from `development` | **Recommended** | Akash sandbox, Vercel preview |
| `devnets` | Broader DePIN devnet testing (IoTeX, Helium, GRASS) | Promotion from `development` | **Recommended** | Devnet RPCs |
| `production` | Pre-mainnet hardened; full QA sign-off | Promotion from `testnet` | **Required** | Akash mainnet (dry-run) |
| `MAINNET` | Final mainnet deployment tag | Promotion from `production` | **Required** | Live infrastructure |

### Feature branches (`cursor/*`)

Cloud Agents create branches matching `cursor/<descriptive-name>-<id>`:

```
cursor/odysseus-brain-e512
cursor/kairo-crypto-pipeline-e512
```

**Rules:**
- Branch off `development` (never off stale `cursor/*` branches)
- One domain per branch — no parallel Vault branches
- PR target: `development` first; coordinator promotes to `main`
- Suffix `-e512` (or similar) is the agent session ID — keep lowercase

---

## Promotion workflow

### Standard path

```bash
# 1. Feature complete on cursor/* → PR to development
git checkout development && git pull origin development
git merge --no-ff origin/cursor/my-feature-e512 -m "feat: my feature"
git push origin development

# 2. Staging validation on testnet
git checkout testnet && git pull origin testnet
git merge --no-ff origin/development -m "promote: development → testnet"
git push origin testnet
# → triggers Akash testnet deploy + Vercel preview

# 3. After QA → production
git checkout production && git merge --no-ff origin/testnet -m "promote: testnet → production"
git push origin production

# 4. After audit → MAINNET
git checkout MAINNET && git merge --no-ff origin/production -m "promote: production → MAINNET"
git push origin MAINNET
```

### Fast-path: sync all env branches to main

When `main` has passed integration review and env branches are behind:

```bash
./scripts/sync-environment-branches.sh
```

### Parallel devnet track

`devnets` can receive experimental DePIN work directly from `development` without blocking the `testnet → production` path:

```bash
git checkout devnets && git merge --no-ff origin/development && git push origin devnets
```

---

## What belongs on each branch

| Branch | Expected contents |
|--------|-------------------|
| `main` | Merged, reviewed, CI-green integration only |
| `development` | Latest features including in-progress Odysseus/Kairo work |
| `testnet` | Same as `development` after smoke tests pass |
| `devnets` | DePIN-specific configs (IoTeX keys, HNT, GRASS node refs) |
| `production` | Frozen deps, Vault paths for prod, no dev fallbacks |
| `MAINNET` | Exact commit deployed to live Akash + Vercel + domains |

---

## Environment-specific configuration

Set these per branch in GitHub Environments or Vault:

| Variable | development | testnet | production | MAINNET |
|----------|-------------|---------|------------|---------|
| `AKASH_CHAIN_ID` | `akashnet-2` | `akashnet-2` | `akashnet-2` | `akashnet-2` |
| `SQUARE_ENVIRONMENT` | `sandbox` | `sandbox` | `production` | `production` |
| `VAULT_NAMESPACE` | `dev` | `staging` | `prod` | `mainnet` |
| `NETWORK_LOCKDOWN_MODE` | `false` | `true` | `true` | `true` |
| `VAULT_TARGET_USD` | `5000000` | `5000000` | `5000000` | `5000000` |

Secrets never live in branch content — only Vault coordinates and `.env.example` placeholders.

---

## Current branch tips (June 15, 2026)

| Branch | Tip commit | Status |
|--------|------------|--------|
| `main` | `ca74492` | ✅ Integration + JWT Codespace workflow |
| `development` | `060f193` | ⚠️ Behind `main` — run sync script |
| `testnet` | `060f193` | ⚠️ Behind `main` |
| `devnets` | `060f193` | ⚠️ Behind `main` |
| `production` | `060f193` | ⚠️ Behind `main` |
| `MAINNET` | `060f193` | ⚠️ Behind `main` |

**Action:** Run `./scripts/sync-environment-branches.sh` to align all environment branches to `main`.

---

## GitHub branch protection (recommended)

### `main`
- Require PR reviews: 1
- Require status checks: CI, smoke tests
- No direct pushes
- Require linear history: optional

### `production`, `MAINNET`
- Require PR reviews: 1
- Require status checks: full integration suite
- Restrict pushes to release managers

### `testnet`, `devnets`
- Require status checks: smoke tests

---

## Cleaning up `cursor/*` branches

After a `cursor/*` branch is merged to `development` and/or `main`:

```bash
# Delete remote branch (after PR merge)
git push origin --delete cursor/my-feature-e512

# Prune local tracking refs
git fetch origin --prune
```

See `MERGE_STRATEGY.md` for the full list of branches to close without merging.

---

## Quick reference commands

```bash
# See all cursor branches ahead of main
./scripts/analyze-cursor-branches.sh

# Sync environment branches to main
./scripts/sync-environment-branches.sh

# Create missing environment branches from main
./scripts/merge-swarm.sh --init-branches-only

# Full merge coordinator (post-consolidation mode)
./scripts/merge-swarm.sh
```
