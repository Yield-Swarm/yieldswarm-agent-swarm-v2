# PR Close Checklist — Post Pillar Merge (2026-06-16)

> Use after `main` is green and env branches synced. Run `bash scripts/close-superseded-prs.sh --dry-run` first.

## Close as superseded (safe)

| PR | Branch | Reason | Link in close comment |
|----|--------|--------|----------------------|
| **#3** | `cursor/akash-tfc-bootstrap-fc5d` | **MERGED** @ `8074651` | `deploy/terraform-tfc/`, `docs/DEPLOYMENT_GUIDE.md` |
| **#38** | `cursor/akash-ollama-worker-625e` | Merged via pillar integration @ `3402ba6` | `deploy/akash/ollama-worker.sdl.yml` |
| **#10** | `cursor/greatdelta-emission-router-1068` | Contract on `main` (`contracts/GreatDeltaEmissionRouter.sol`, 510 lines) | `backend/src/adapters/emissionRouter.js` |
| **#43** | `cursor/zk-entropy-proof-597f` | Superseded by #44 Mayhem Mode | `docs/MAYHEM_14_PILLAR_ZK.md`, `MutationController.sol` |
| **#41** | `cursor/god-prompt-helical-build-d1cd` | Draft; superseded by #44 + AgentSwarm OS | Defer to Q3 helical review |

## Partial extract only (do not full merge)

| PR | Branch | Action |
|----|--------|--------|
| **#8** | `cursor/multicloud-fallback-6923` | Extract GCP MIG + Runpod modules → `deploy/terraform-tfc/modules/`; close after cherry-pick |
| **#4** | `cursor/arena-telemetry-dashboard-c904` | See `docs/ARENA_TELEMETRY_MERGE_PLAN.md` |
| **#9** | `cursor/arena-akash-telemetry-f187` | See `docs/ARENA_TELEMETRY_MERGE_PLAN.md` |

## Defer

| PR | Notes |
|----|-------|
| **#36, #34, #32, #31** | High conflict — rebase individually after arena land |
| **#30, #29, #28** | CI failures — fix on fresh branch off `main` |

## Verification before close

```bash
git fetch origin main
git checkout main && git pull

# Superseded checks (three-dot diff should be subset of main)
git diff main...origin/cursor/greatdelta-emission-router-1068 --stat
git diff main...origin/cursor/zk-entropy-proof-597f --stat -- contracts/ src/infrastructure/

npm run test:unit && cd backend && npm test
bash scripts/sync-environment-branches.sh --dry-run
```

## Branch deletion (optional, after close)

```bash
# Local
git branch -d cursor/akash-tfc-bootstrap-fc5d 2>/dev/null || true
git branch -d cursor/akash-ollama-worker-625e 2>/dev/null || true

# Remote (only after PR closed + no open dependents)
git push origin --delete cursor/greatdelta-emission-router-1068
git push origin --delete cursor/zk-entropy-proof-597f
git push origin --delete resolve/akash-tfc-pr3  # resolution branch, if merged
```

## Integration branch cleanup

```bash
git push origin --delete integration/2026-06-16  # after main contains all landed work
```

## Notion / Linear handoff fields

- **Integration status:** Pillar merge complete; TFC modular; Arena telemetry in progress
- **Open PRs:** #4, #9 (arena), #8 (multicloud extract)
- **Bounty:** `docs/BUG_BOUNTY_V1.md` ready for council review
- **Tests:** 31/31 vitest + 20/20 backend @ `8074651`
