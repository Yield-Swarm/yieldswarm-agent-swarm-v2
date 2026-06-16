# Arena Telemetry — Ethical Merge Plan (PR #4 + PR #9)

> **Target:** `main` @ post–pillar merge (ZK Mayhem Mode + MutationController + TFC bootstrap)  
> **Branches:** `cursor/arena-telemetry-dashboard-c904` (#4), `cursor/arena-akash-telemetry-f187` (#9)  
> **Strategy:** Selective port — **do not** merge stale branches wholesale (3-dot diff shows only 1–2 unique files each; branches are hundreds of commits behind `main`).

## Swarm verdict

| PR | Unique value on branch | Recommendation |
|----|------------------------|----------------|
| **#4** | `app/arena/page.tsx` (693 lines) + `NEXT_PUBLIC_WORKER_URLS` | Port worker URL probe pattern only if not redundant with `frontend/` Arena |
| **#9** | `app/arena/page.tsx` (840 lines) — lease polling, VRAM/metrics, treasury velocity | **High priority:** port lease polling + worker health to backend API + React Arena |
| **Both** | No Mayhem/ZK hooks on branches | **Add new:** ZK Mayhem + Helix cards on current `frontend/src/routes/Arena.tsx` |

## What `main` already has

- `frontend/src/routes/Arena.tsx` + `useArenaTelemetry.ts` → `GET /api/arena/overview`
- `backend/src/adapters/akash.js` — Console indexer + owner leases
- `app/arena/page.tsx` — minimal Next.js worker health probe (from TFC merge)
- Helix, Great Delta, cross-chain in overview payload

## What to port from PR #9 (ethical extraction)

1. **Lease → worker URL extraction** (`fetchWorkerLeases`, `extractWorkerUrlsFromLease`)
2. **Per-worker poll** — `/metrics`, `/api/ps`, agent count endpoints
3. **Reconnect/backoff** — client-side in React hook OR server-side cache in backend
4. **Env vars** — move secrets server-side:
   - `AKASH_LEASES_URL` (backend only, not `NEXT_PUBLIC_*`)
   - `TREASURY_VELOCITY_URL` (optional)

## What NOT to port

- Entire monolithic `app/arena/page.tsx` (duplicates `frontend/` Arena)
- Any quarantined Arena state or pre–air-gap telemetry leaks
- Stale `.env.example` / Makefile / doc deletions from branch tip

## Exact commands

```bash
# Step 0 — Recon (three-dot diff = unique commits on PR branch only)
git fetch origin main \
  cursor/arena-telemetry-dashboard-c904 \
  cursor/arena-akash-telemetry-f187

git diff main...origin/cursor/arena-telemetry-dashboard-c904 --stat
git diff main...origin/cursor/arena-akash-telemetry-f187 --stat

# Step 1 — Clean resolution branch
git checkout main && git pull origin main
git checkout -b cursor/arena-telemetry-merge-4f85

# Step 2 — Extract PR #9 lease polling into backend (preferred)
git show origin/cursor/arena-akash-telemetry-f187:app/arena/page.tsx \
  > /tmp/pr9-arena-page.tsx
# Manually port: fetchWorkerLeases, pollWorker, metrics parsers
# → backend/src/adapters/arenaLiveWorkers.js
# → GET /api/arena/live-workers

# Step 3 — Extend React Arena (already on main)
# Edit: frontend/src/hooks/useArenaTelemetry.ts (types + optional live-workers poll)
# Edit: frontend/src/routes/Arena.tsx (VRAM, models, Mayhem/Helix cards)

# Step 4 — Wire ZK Mayhem observability (new, not on PR branches)
# backend/src/adapters/zkMayhem.js → arena/overview field `zkMayhem`
# Surface: circuit built, min quality, last proof commitment (no raw VRAM)

# Step 5 — Verify
npm run test:unit
cd backend && npm test
npm run test:frontend
# Optional with backend up:
curl -s http://127.0.0.1:8080/api/arena/overview | jq '.zkMayhem,.helix.phase'

# Step 6 — Commit & land
git add backend/src/adapters/arenaLiveWorkers.js \
        backend/src/adapters/zkMayhem.js \
        backend/src/routes/api.js \
        frontend/src/hooks/useArenaTelemetry.ts \
        frontend/src/routes/Arena.tsx
git commit -m "feat(arena): selective live Akash telemetry + ZK Mayhem hooks (PR #4/#9 ethical port)"
git push -u origin cursor/arena-telemetry-merge-4f85
```

## File mapping

| PR #9 source | Target on `main` |
|--------------|------------------|
| `fetchWorkerLeases` | `backend/src/adapters/arenaLiveWorkers.js` |
| `pollWorker` / metrics parsers | same |
| Dashboard state machine | `frontend/src/hooks/useArenaLiveWorkers.ts` (new) |
| Treasury velocity fetch | `backend/src/adapters/treasury.js` or overview field |
| `NEXT_PUBLIC_AKASH_LEASES_URL` | `AKASH_LEASES_URL` in backend `config.js` |

## ZK / Mayhem integration (post-merge additions)

```javascript
// arena/overview payload extension
{
  "zkMayhem": {
    "enabled": true,
    "circuitBuilt": true,
    "minEntropyQuality": 0.5,
    "mutationIntervalMs": 604800000,
    "lastCommitment": "0x..." // from .run/zk-mutation.json if present
  },
  "helix": { /* existing getHelixStatus() */ }
}
```

Arena cards to add:

- **Mayhem intensity** — entropy quality, proof success/fail (from scheduler webhook log)
- **Helix phase** — genesis hash, readiness score (already in overview)
- **Mutation coverage** — % workers with valid proofs in last 24h

## Security review checklist

- [ ] No raw GPS or driver PII in Arena public endpoints
- [ ] Lease URLs never exposed via `NEXT_PUBLIC_*`
- [ ] Worker metrics polled server-side with timeout + SSRF guard (allowlist hosts)
- [ ] ZK proofs: expose commitment + public signals only, not witness inputs
- [ ] Rate limit `GET /api/arena/live-workers` (cache 10s TTL)

## After merge

Close PR #4 and #9 with:

> Selectively integrated on `cursor/arena-telemetry-merge-4f85` — live lease polling + ZK Mayhem hooks ported to `frontend/` Arena and `/api/arena/overview`. Full branch not merged (stale vs main).

## Bounty angle

Live Arena + ZK proofs enable researchers to attach `arena_session_id` + `commitment` to bounty submissions → automated verification via `services/neon_store.py` correlation.
