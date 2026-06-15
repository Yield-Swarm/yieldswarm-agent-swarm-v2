# YieldSwarm Swarm Merge Strategy

> Master Merge Coordinator — updated June 15, 2026  
> Repo: `yieldswarm-agent-swarm-v2`  
> Status: **CONSOLIDATED** — 18 canonical `cursor/*` branches merged; `main` promotion in progress

## Current State (June 15, 2026)

| Branch | Files | Status |
|--------|-------|--------|
| `cursor/merge-coordination-93dd` | ~545 | ✅ Integration complete |
| `development`, `testnet`, `devnets`, `production`, `MAINNET` | ~545 | ✅ Synced to integration |
| `main` | ~545 | 🔄 Promoted via `cursor/mega-task-consolidation-f9c3` |
| 25 duplicate `vault-integration-*` | — | ❌ Close without merge |
| 7 superseded cursor branches | — | ❌ Documented below |

**Mega Task Round (M1–M6) additions on consolidation branch:**

- **M1** — `scripts/deploy-vault-production.sh`, Vault-first `DEPLOY.md` section, monolith SDL + Odysseus
- **M2** — `kairo/` + `src/lib/kairo/` + `/api/kairo/*` + `/kairo` dashboard
- **M3** — `services/odysseus/main.py` orchestrator, `docker-compose.odysseus-full.yml`
- **M4** — Kairo trip fees (1% customer / 2× driver), Wise instant cashout API
- **M5** — this document + `scripts/merge-swarm.sh`
- **M6** — `DOMAINS.md` with Vercel + Akash + crypto records

---

## Branch Inventory by Domain

### Tier 0 — Foundation (merge first)

| Branch | Commits | Files | Purpose | Status |
|--------|---------|-------|---------|--------|
| `cursor/vault-integration-1b83` | 6 | 42 | **Canonical Vault** — policies, bootstrap, Terraform, Akash runtime injection, SECRETS.md | ✅ **SELECTED** |
| `cursor/complete-vault-integration-82c9` | 4 | 51 | Modular Terraform layout (alternate structure) | ⚠️ Superseded by 1b83 |
| `cursor/hashicorp-vault-integration-9286` | 1 | 45 | Vault + lib/secrets.py + agent runners | ⚠️ Duplicate — skip |
| + 25 other `vault-integration-*` / `hashicorp-vault-integration-*` | 1–4 | 13–45 | Same Vault work, parallel agents | ❌ **CLOSE without merge** |

**Vault winner:** `cursor/vault-integration-1b83` — most complete (6 commits, 2,906 lines, operator runbook, GitOps Terraform config).

### Tier 1 — Core Platform (merge after Vault)

| Branch | Commits | Files | Purpose | Conflicts |
|--------|---------|-------|---------|-----------|
| `cursor/unified-wallet-system-690e` | 5 | 37 | Vite+React frontend, multi-chain wallet (EVM/Solana/TON/BTC) | None |
| `cursor/build-payment-rails-5087` | 7 | 65 | Next.js payment app — Square, Wise, Web3 on/off-ramp | `.gitignore` (trivial) |
| `cursor/agents-arena-system-21fb` | 2 | 188 | 169 deity manifests, mutation engine, leaderboard API | None |
| `cursor/production-deploy-orchestrator-85ce` | 1 | 43 | Makefile, deploy.sh, monitoring stack, DEPLOY.md | `.gitignore` (trivial) |

### Tier 2 — Akash + Odysseus (merge in parallel after Tier 1)

| Branch | Commits | Files | Purpose | Conflicts |
|--------|---------|-------|---------|-----------|
| `cursor/add-odysseus-deployments-edbd` | 3 | 22 | Odysseus Docker, Akash SDL, GHCR workflow, Vault deploy | `.gitignore` |
| `cursor/akash-lease-manager-f88c` | 1 | 12 | RTX 3090 lease manager, auto-failover, telemetry | `akash/README.md`, `akash-optimizer.py` |
| `cursor/yieldswarm-akash-model-routing-9698` | 2 | 9 | RTX 3090 model router + API | `akash-optimizer.py`, `services/__init__.py` |
| `cursor/odysseus-chromadb-memory-d634` | 1 | 14 | ChromaDB memory mesh for 10,080 agents | `akash-optimizer.py`, agent entrypoints |
| `cursor/yieldswarm-odysseus-tools-3c2a` | 1 | 10 | Odysseus tool definitions + MCP server | `agents/__init__.py` |
| `cursor/integrate-odysseus-1074` | 1 | 15 | LiteLLM router, SearXNG, swarm manifest | `docker-compose.yml`, `.gitignore` |
| `cursor/odysseus-ui-integration-35ff` | 1 | 13 | Arena/Portal static frontend + auth | `frontend/arena/*`, `package.json` |
| `cursor/harden-akash-sdl-worker-ff04` | 1 | 4 | Hardened worker Dockerfile + monolith SDL | None |

### Tier 3 — Sovereign + Treasury + Telemetry

| Branch | Commits | Files | Purpose | Conflicts |
|--------|---------|-------|---------|-----------|
| `cursor/iteration-100-sovereign-loops-6c60` | 2 | 7 | Self-healing leases, treasury rebalance, mutation loops | `akash-optimizer.py` |
| `cursor/iteration-100-sovereign-core-fede` | 2 | 13 | $5M vault dashboard, delta grid marketplace | None |
| `cursor/arena-live-data-integration-f19d` | 2 | 20 | Backend API fusing Akash + on-chain telemetry | None |
| `cursor/great-delta-emission-router-4594` | 1 | 3 | Solidity emission router + deploy scripts | None |
| `cursor/trident-layer35-foundation-8f92` | 1 | 22 | Trident Layer-35 blueprint, quadrant-IV contracts | `README.md` |

### Tier 4 — Multi-Cloud Infra

| Branch | Commits | Files | Purpose | Notes |
|--------|---------|-------|---------|-------|
| `cursor/multicloud-fallback-infra-e3ca` | 1 | 30 | Azure VMSS, GCP MIG, RunPod, Vultr Terraform + Packer | ✅ **SELECTED** |
| `cursor/multicloud-fallback-6923` | 1 | 26 | Similar multi-cloud (less complete) | ⚠️ Skip — use e3ca |

### Branches to Skip (duplicates or superseded)

| Branch | Reason |
|--------|--------|
| All 25 other `vault-integration-*` / `hashicorp-vault-integration-*` | Duplicate Vault work |
| `cursor/complete-vault-integration-8887` | Subset of 82c9/1b83 |
| `cursor/greatdelta-emission-router-1068` | Duplicate of 4594 |
| `cursor/arena-akash-telemetry-f187` | Single `app/arena/page.tsx` — superseded by arena-live-data |
| `cursor/arena-telemetry-dashboard-c904` | Superseded by arena-live-data |
| `cursor/akash-tfc-bootstrap-fc5d` | Overlaps production-deploy + harden-akash |
| `cursor/multicloud-fallback-6923` | Superseded by infra-e3ca |

---

## Merge Order (Tested)

```
1.  cursor/vault-integration-1b83              [foundation]
2.  cursor/unified-wallet-system-690e          [frontend wallet]
3.  cursor/build-payment-rails-5087            [payments]
4.  cursor/agents-arena-system-21fb            [agent arena]
5.  cursor/production-deploy-orchestrator-85ce [deploy orchestrator]
6.  cursor/add-odysseus-deployments-edbd       [odysseus deploy]
7.  cursor/iteration-100-sovereign-loops-6c60  [sovereign loops]
8.  cursor/iteration-100-sovereign-core-fede   [$5M dashboard]
9.  cursor/akash-lease-manager-f88c            [lease manager]
10. cursor/arena-live-data-integration-f19d    [live telemetry API]
11. cursor/odysseus-chromadb-memory-d634       [memory mesh]
12. cursor/yieldswarm-odysseus-tools-3c2a      [odysseus tools]
13. cursor/yieldswarm-akash-model-routing-9698 [model router]
14. cursor/multicloud-fallback-infra-e3ca      [multi-cloud]
15. cursor/great-delta-emission-router-4594    [emission router]
16. cursor/trident-layer35-foundation-8f92     [trident blueprint]
17. cursor/integrate-odysseus-1074             [odysseus stack]
18. cursor/odysseus-ui-integration-35ff        [arena/portal UI]
19. cursor/harden-akash-sdl-worker-ff04        [worker hardening]
```

Run via: `scripts/merge-swarm.sh` (or merge the integration PR).

### Promote integration to `main`

```bash
git checkout main
git merge --no-ff origin/cursor/merge-coordination-93dd -m "Merge swarm integration into main"
git push origin main

# Sync environment branches from main
for b in development testnet devnets production MAINNET; do
  git checkout "$b" && git merge --ff-only main && git push origin "$b"
done
```

### Known Conflict Resolutions

| File | Resolution |
|------|------------|
| `.gitignore` | Union of all patterns (Vault + Node + Python) |
| `agents/akash-optimizer.py` | Combined: sovereign loops + Odysseus memory + model router |
| `agents/chainlink-vault-manager.py` | Combined: treasury rebalance + Odysseus performance recording |
| `agents/openclaw-scaler.py` | Combined: mutation loop + Odysseus mesh registration |
| `akash/README.md` | Vault README + lease manager section appended |
| `README.md` | Keep integration branch version (richest docs) |
| `contracts/GreatDeltaEmissionRouter.sol` | Keep both: root `contracts/` + `contracts/quadrant-iv/` (Trident) |

---

## Secret Management (Vault)

**Single source of truth:** HashiCorp Vault via `cursor/vault-integration-1b83`.

### Rules

1. **Never merge branches containing real secrets** — audit before merge.
2. All runtime secrets injected via Vault Agent sidecar (`akash/vault-agent.hcl`).
3. Terraform pulls provider credentials from Vault paths (see `SECRETS.md`).
4. `.env` and `*.tfvars` are gitignored; only `.env.example` with placeholders ships.
5. Odysseus secrets: `kv/data/yieldswarm/odysseus/runtime` and `/deploy`.
6. Payment rails: Square/Wise keys via Vault or Vercel env (never committed).

### Pre-merge secret audit

```bash
git diff main...origin/<branch> | grep -iE '(api[_-]?key|secret|password|private[_-]?key|token)\s*[:=]\s*["\x27][^"\x27]{8,}'
```

---

## Environment Branch Strategy

| Branch | Purpose | Protection | Promoted From |
|--------|---------|------------|---------------|
| `main` | Clean integration for cloud deployment | **Yes** — PR + status checks | Merge coordination PR only |
| `development` | Daily active development | No | `main` (initial), then direct pushes/PRs |
| `testnet` | Akash testnet, staging Vercel | Yes | `development` when stable |
| `devnets` | Broader devnet testing (IoTeX, HNT, GRASS) | Yes | `development` |
| `production` | Pre-mainnet hardened | Yes | `testnet` after QA |
| `MAINNET` | Final mainnet deployment | Yes | `production` after audit |

### Promotion flow

```
development → testnet → production → MAINNET
     ↑              ↑
  devnets      (parallel test track)
```

`main` receives only merge-coordination PRs. Feature agents target `development`.

---

## Kairo Integration

Kairo (driver-first marketplace) lives in this monorepo:

- `kairo/` — Python identity + signing (IoTeX + EVM)
- `src/lib/kairo/` — TypeScript models, Mandelbrot router, fees
- `src/app/api/kairo/` — driver register, telemetry, trips, cashout
- `src/app/kairo/` — driver dashboard (contributions + earnings)
- Shares `src/lib/payments/` (Square, Wise) and `frontend/src/wallet/` (Web3)

Recommended path: customer-facing Kairo app with Mapbox on `development` next.

---

## Post-Merge Manual Review Checklist

- [ ] Enable `main` branch protection on GitHub
- [ ] Close 25 duplicate Vault PRs without merging
- [ ] Run `cd frontend && npm install && npm run build`
- [ ] Run `npm install && npm run build` (payments app)
- [ ] Run `cd backend && npm test`
- [ ] Run `python -m pytest tests/` (agent tests)
- [ ] Verify `docker-compose.yml` starts Odysseus locally
- [ ] Review `contracts/` for duplicate GreatDelta routers — consolidate before mainnet
- [ ] Wire Arena React (`frontend/src/routes/Arena.tsx`) to `backend/` telemetry API
- [ ] Remove duplicate static `frontend/arena/` once React Arena is wired

---

## Agent Coordination Going Forward

1. **One agent per domain** — no more parallel Vault branches.
2. All new work branches off `development`, PRs to `development`.
3. Merge coordination agent runs weekly or when >5 cursor branches accumulate.
4. Kairo work uses `cursor/kairo-*` prefix, targets `development`.
