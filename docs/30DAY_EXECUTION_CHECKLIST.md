# 30-Day Master Execution Checklist

Single tracker combining **human gates**, **agent swarm tasks**, and **multi-cloud deployment** for the maximum-utilization window.

**Start date:** _____________  
**Target end:** _____________ (+30 days)

---

## How to use

1. Complete **Phase 0** (human gates) before scaling agents.
2. Run **daily ops** every morning (`make multicloud-preflight` + `make multicloud-cost-report`).
3. Check off items as done. Update the Swarm Conductor after each phase.
4. Full strategy: `docs/MULTI_CLOUD_30DAY_PLAN.md`

---

## Phase 0 — Human gates (Day 0–1) — BLOCKS EVERYTHING

| # | Task | Command / action | Done |
|---|------|------------------|------|
| 0.1 | Vault token exported (never commit) | `export VAULT_ADDR=https://vault.yieldswarm.io:8200` + `VAULT_TOKEN=...` | [ ] |
| 0.2 | Akash wallet funded ≥0.5 AKT | Fund `yieldswarm-admin` key in `deploy/akash.env` | [ ] |
| 0.3 | Shard ID set | `export AGENT_SHARD_ID=0` | [ ] |
| 0.4 | Akash preflight GO | `make akash-preflight` | [ ] |
| 0.5 | Cloud API keys in Vault | RunPod, Vast, Azure, GCP keys via `vault kv put` | [ ] |
| 0.6 | Cursor MCP loaded | Copy `.cursor/mcp-config-top12.json` → Cursor settings | [ ] |
| 0.7 | Swarm Conductor agent open | Paste prompt from `docs/SWARM_CONDUCTOR.md` | [ ] |

### Copy-paste (after wallet funded)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<your-token>
export AGENT_SHARD_ID=0
make akash-preflight
make multicloud-preflight
```

---

## Phase 1 — Akash live (Days 1–3) — HIGHEST PRIORITY

| # | Task | Command | Done |
|---|------|---------|------|
| 1.1 | Live europlots deploy | `make deploy-akash-europlots` | [ ] |
| 1.2 | Post-deploy verify | `make akash-verify` | [ ] |
| 1.3 | Lease env sourced | `source .run/akash-lease.env` | [ ] |
| 1.4 | Arena wired | Open `/arena?workers=${AKASH_WORKER_URLS}` | [ ] |
| 1.5 | Sovereign loops up | `make sovereign-up` | [ ] |
| 1.6 | Monitoring up | `make monitoring-up` | [ ] |
| 1.7 | Bittensor axon reachable | curl `:8091` or verify in `akash-verify` | [ ] |
| 1.8 | Merge PR stack | #25 → #27 → #28 → #29 → #30 | [ ] |

---

## Phase 2 — Cursor + agent swarm (Days 2–7)

| # | Task | Doc / branch | Done |
|---|------|--------------|------|
| 2.1 | MCP top-12 config active | `.cursor/mcp-config-top12.json` | [ ] |
| 2.2 | Swarm Conductor coordinating | `docs/SWARM_CONDUCTOR.md` | [ ] |
| 2.3 | Multi-cloud plan merged | PR `cursor/multi-cloud-30day-plan-9c82` | [ ] |
| 2.4 | Tesla Fleet keys deployed | `make tesla-keys` + Vercel deploy | [ ] |
| 2.5 | Tesla domain registered | `make tesla-register` (real creds) | [ ] |
| 2.6 | Kairo frontend live | Kairo PR #29 merged + Mapbox token | [ ] |
| 2.7 | Funding folder counsel review | `funding/` — do not send without counsel | [ ] |

---

## Phase 3 — GPU scale + revenue (Days 8–14)

| # | Task | Provider | Done |
|---|------|----------|------|
| 3.1 | Second Akash worker / miner SDL | Akash | [ ] |
| 3.2 | Vast.io training pod launched | Vast | [ ] |
| 3.3 | RunPod inference pod launched | RunPod | [ ] |
| 3.4 | First Bittensor emission logged | Akash/Vast | [ ] |
| 3.5 | Cost report baseline | `make multicloud-cost-report` | [ ] |
| 3.6 | Daily budget alerts configured | `config/multicloud/budgets.env` | [ ] |
| 3.7 | `make scale-akash-workers` or lease-manager | Akash | [ ] |

---

## Phase 4 — DePIN + training burst (Days 15–21)

| # | Task | Provider | Done |
|---|------|----------|------|
| 4.1 | Grass node(s) online | Azure or GCP | [ ] |
| 4.2 | Model fine-tune job completed | Vast/RunPod | [ ] |
| 4.3 | Fallback terraform tested | `infra/terraform/` | [ ] |
| 4.4 | Postgres payments (God Prompt G) | Neon | [ ] |
| 4.5 | Sovereign metrics hardened (God Prompt H) | `sovereign_runtime.py` | [ ] |
| 4.6 | Tesla telemetry follow-up | vehicle pairing + ingest | [ ] |

---

## Phase 5 — Optimize + prove revenue (Days 22–30)

| # | Task | Done |
|---|------|------|
| 5.1 | Idle burst pods torn down | [ ] |
| 5.2 | Workloads shifted to cheapest provider | [ ] |
| 5.3 | Revenue / emissions dashboard in Arena | [ ] |
| 5.4 | Credit utilization ≥70% documented | [ ] |
| 5.5 | Alibaba filler (if credits remain) | [ ] |
| 5.6 | `funding/` updated with live traction | [ ] |
| 5.7 | 30-day retrospective written | [ ] |

---

## Daily ops (repeat every day)

```bash
make multicloud-preflight
make multicloud-cost-report
make akash-verify          # if Akash lease active
make status                # sovereign + monitoring
```

| Date | Preflight | Cost report | Notes |
|------|-----------|-------------|-------|
| | GO / NO-GO | $_____ | |
| | GO / NO-GO | $_____ | |
| | GO / NO-GO | $_____ | |

---

## Merge order (enforce)

```
vault-akash-injection → production-prep (#25) → god-prompt-swarm (#27)
  → akash-real-deploy (#28) → kairo (#29) → tesla-fleet (#30)
  → multi-cloud-30day → sovereign-loops-live → main
```

---

## Definition of done (30 days)

- [ ] Live Akash lease with Vault injection + Bittensor telemetry
- [ ] ≥2 GPU workers across Akash + (Vast or RunPod)
- [ ] Grass or DePIN node producing rewards
- [ ] One completed training / fine-tune run
- [ ] Sovereign loops + Arena showing real worker data
- [ ] Cost tracking with documented credit burn
- [ ] Funding materials updated with verifiable traction

---

## Quick refs

| Doc | Purpose |
|-----|---------|
| `docs/FINAL_DEPLOYMENT_RUNBOOK.md` | Merge + smoke + sovereign activation |
| `docs/MULTI_CLOUD_30DAY_PLAN.md` | Full strategy + week-by-week plan |
| `docs/CURSOR_CLOUD_SETUP.md` | MCP + parallel agent setup |
| `docs/SWARM_CONDUCTOR.md` | Meta-agent prompt |
| `TODAY_EXECUTION_PLAN.md` | Day-one P0 checklist |
| `docs/AKASH_DEPLOY.md` | Akash production guide |
| `docs/TESLA_FLEET_INTEGRATION.md` | Tesla keys + registration |
