# Final Deployment Runbook — Merge + Smoke + Sovereign Consensus

One-page execution guide after all Cursor agent work is complete.

---

## Human gates (cannot be automated)

| Gate | Action |
|------|--------|
| Vault | `export VAULT_ADDR=https://vault.yieldswarm.io:8200` + `export VAULT_TOKEN=...` |
| Akash wallet | Fund **≥ 0.5 AKT** to key in `deploy/akash.env` |
| Cloud API keys | RunPod, Vast, etc. in Vault `kv/yieldswarm/cloud/*` |
| PR review | Merge stacked PRs in order (or use merge script) |

---

## Step 1 — Safe merge (correct order)

### Dry run first

```bash
./scripts/merge-all-prs.sh --dry-run
# or
make merge-all-prs
```

### Core merge sequence

| Order | Branch | Into |
|-------|--------|------|
| 1 | `cursor/vault-akash-injection-9c82` | `cursor/production-prep-9c82` |
| 2 | `cursor/production-prep-9c82` | `main` |
| 3 | `cursor/god-prompt-swarm-9c82` | `main` |
| 4 | `cursor/sovereign-loops-live-9c82` | `main` |
| 5 | `cursor/akash-real-deploy-9c82` | `main` |

### Execute

```bash
# Local merges only
./scripts/merge-all-prs.sh

# Merge + push main
./scripts/merge-all-prs.sh --push

# Also merge kairo (#29), tesla (#30), multicloud (#31)
./scripts/merge-all-prs.sh --push --include-optional
```

On conflict: resolve manually, commit, re-run script (already-merged steps are skipped).

---

## Step 2 — Master smoke test

```bash
make smoke
# strict mode (warnings = failure):
STRICT=1 make smoke
```

Covers:

1. `scripts/smoke-test.sh` — structural + pytest + vitest
2. `scripts/verify-vault-injection.sh` — Vault policies, SDL refs, AppRole
3. `scripts/akash-preflight.sh` — GO/NO-GO (after akash-real-deploy merged)
4. `scripts/verify-akash-lease.sh` — live lease probes
5. Sovereign one-shot (`swarm_runner.py` or `sovereign_runtime.py`)
6. Optional backend/Kairo health if running locally

---

## Step 3 — Activate Sovereign Consensus

```bash
make start-sovereign-consensus
make status
make logs
```

Aliases:

```bash
make sovereign-up              # same as start-sovereign-consensus
make restart-sovereign-consensus
make stop-sovereign-consensus
```

Starts:

- `deploy/runtime/swarm_runner.py` — agent orchestration loop
- `deploy/akash/auto-heal.sh` — Akash lease auto-heal (if `.run/akash-lease.env` exists)

---

## Step 4 — Live Akash deploy (revenue path)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<token>
export AGENT_SHARD_ID=0

make akash-preflight          # must be GO
make deploy-akash-europlots
make akash-verify
source .run/akash-lease.env
echo "Arena: /arena?workers=${AKASH_WORKER_URLS}"
```

---

## Quick reference

| Command | Purpose |
|---------|---------|
| `make merge-all-prs` | Dry-run stacked merge plan |
| `make smoke` | Full post-merge validation |
| `make start-sovereign-consensus` | Start autonomous loops |
| `make akash-preflight` | Pre-deploy GO/NO-GO |
| `make deploy-akash-europlots` | Live mainnet lease |
| `make multicloud-preflight` | Multi-cloud readiness |

---

## Related docs

- `docs/30DAY_EXECUTION_CHECKLIST.md` — 30-day tracker
- `docs/SWARM_CONDUCTOR.md` — parallel agent coordination
- `docs/AKASH_DEPLOY.md` — full Akash guide
- `MERGE_STRATEGY.md` — branch topology
