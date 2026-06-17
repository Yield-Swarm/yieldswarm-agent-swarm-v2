# Royal Decree — 30-Day Revenue Sprint

> **Activated:** June 15, 2026  
> **Operational frequency:** ValhallA portal + Helix Chain + light-and-love guardianship  
> **Primary target:** Combined **7-day foundation sprint** → compound through Day 30

This document is the executable decree for the ~**$5,400+ free-credit** multi-cloud stack. It maps your Royal Decree providers to **repo commands that exist today**, wires **Spheres of Harmony** and the **ancestral chain** into the agent swarm, and names the **first launch sequence**.

---

## Recommendation: launch this first

**Start with the combined 7-day sprint** (Section 3 below), not a single provider in isolation.

| Priority | What | Why |
|----------|------|-----|
| **1** | Akash Tier B (Bittensor miner SDL) | Fastest path to GPU revenue + Arena telemetry; DePIN-aligned |
| **2** | Helix Chain activation (`activate-helix.sh`) | Spheres of Harmony + ancestral genesis receipt on disk |
| **3** | Vercel production payments | First fiat conversion while GPU warms up |
| **4** | Vast.ai burst (Week 2) | Cheap overflow training when Akash bids are thin |
| **5** | $1 micro-revenue test (Day 7) | Proves end-to-end payment rail before scaling credits |

Akash + Helix + one paid conversion in Week 1 beats spinning up five providers with no revenue signal.

---

## 1. Credit inventory (Royal Decree stack)

Approximate free-credit map — store API keys in **Vault only** (`vault kv put yieldswarm/cloud/<provider> ...`).

| Provider | Est. credit | Repo wiring | Sprint role |
|----------|-------------|-------------|---------------|
| **Akash** | Wallet-funded (decentralized) | `make deploy-akash-europlots`, SDL tiers | **Week 1 P0** — GPU + Bittensor |
| **Vast.ai** | ~$500–1,000 typical promos | Vault `cloud/vast`; see `docs/MULTI_CLOUD_30DAY_PLAN.md` | Week 2 burst training |
| **Salad** | GPU share credits | Manual console; bridge via worker telemetry | Week 2–3 GPU overflow |
| **Cherry Servers** | Bare-metal promos | Terraform `terraform/` (Vultr/DO patterns) | Week 2–3 dedicated GPU |
| **Polrunner / Hushki** | Niche GPU promos | Vault + custom launch script | Week 3 filler |
| **AWS** | ~$1,000–2,000 | `terraform/modules/`, future ECS | Week 3 training burst |
| **Azure** | ~$500–1,500 | `make azure-apply`, `terraform/azure.tf` | Control plane + Grass |
| **Google Cloud** | ~$300–1,000 | `terraform/modules/gcp` | Training / MIG fallback |
| **Alibaba** | ~$300–500 | `scripts/multicloud/providers/alibaba.sh` (branch) | Week 4 filler only |
| **HashiCorp Vault** | HCP trial / self-hosted | `make vault-bootstrap`, `make seed-vault` | **Day 0** — secrets hub for all |

**Budget discipline:** Tier A backend (~$45–75/mo) + Tier B miner (~$230–350/mo) ≈ **$275–425/mo** on Akash. At that burn, $5,400 credits last **12–18 months** if you avoid idle burst pods.

---

## 2. Spheres of Harmony + ancestral chain (repo mapping)

These are not separate greenfield services — they wire into code already on `main`:

### Spheres of Harmony

| Sphere | Repo implementation | Activate |
|--------|---------------------|----------|
| **Genesis / sovereignty** | Helix Chain adapter → `dashboard/helix-state.json` | `./scripts/activate-helix.sh` |
| **Harmony scoring** | Kairo `tree_of_life_projection()` → `harmony_index` | Auto when Kairo telemetry flows |
| **Emission routing** | Great Delta / `emissionRouter.js` | Set `HELIX_EMISSION_ROUTER` or Solana/EVM router env |
| **Worker balance** | Arena + sovereign loops | `make sovereign-up` · `/arena?workers=...` |
| **Solar-lunar / prophetic** | Sovereign runtime + cron harvest | `deploy/scripts/start-sovereign-loops.sh` |

Harmony index formula (existing):

```python
# kairo/services/pipeline.py — harmony_index rises when shard weights are balanced
harmony = 1.0 - (max(normalized.values()) - min(normalized.values()))
```

Target: **`harmony_index ≥ 0.85`** on live Kairo telemetry before scaling to Tier C (full Odysseus).

### Deep ancestral chain

| Layer | Implementation | Sprint action |
|-------|----------------|---------------|
| **Genesis receipt** | `helix-state.json` genesis hash | `activate-helix.sh` Day 1 |
| **Agent memory** | Odysseus ChromaDB (Tier C SDL) | Week 2 if inference revenue justifies |
| **Immutable archive** | IPFS / Pinata (Council Wishlist) | Pin activation receipt + SDL manifest Day 3 |
| **Truth oracle** | Odysseus brain `:8090` + SearXNG | Tier C or local `services/odysseus/brain.py` |
| **Referral / portal** | ValhallA = production frontend + Arena | Vercel `production` branch + `/arena` |

---

## 3. Combined 7-day sprint (Days 1–7)

### Day 0 — Human gates (blocks everything)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<your-token>   # never commit
export AGENT_SHARD_ID=0

# Fund Akash wallet ≥ 0.5 AKT to yieldswarm-admin
make akash-preflight          # must print GO
```

Also seed Vault paths for burst providers (when ready):

```bash
vault kv put yieldswarm/cloud/vast api_key=<key>
vault kv put yieldswarm/cloud/runpod api_key=<key>
```

Refs: `TODAY_EXECUTION_PLAN.md`, `docs/VAULT_AKASH_RUNTIME.md`

---

### Day 1 — Helix genesis + Akash Tier B deploy

**Morning — ancestral layer first:**

```bash
./scripts/activate-helix.sh
curl -s http://127.0.0.1:8080/api/helix/status | jq '.phase, .readinessScore, .genesisHash'
```

**Afternoon — first GPU revenue node:**

```bash
./scripts/deploy-akash-tier.sh bittensor
# or: make deploy-akash-europlots  (monolith / europlots path)
make akash-verify
source .run/akash-lease.env
```

**Exit criteria:** `helix-state.json` shows `activated: true`; `akash-verify` → GO; worker URL in `.run/akash-lease.env`.

---

### Day 2 — Arena + sovereign loops + monitoring

```bash
make sovereign-up
make monitoring-up
```

Open Arena with live workers:

```
/arena?workers=${AKASH_WORKER_URLS}
```

Verify Kairo harmony telemetry:

```bash
curl -s "http://<worker>:8091/health" 2>/dev/null || true
# harmony_index appears in Kairo projection when telemetry flows
```

Refs: `docs/SWARM_CONDUCTOR.md`, `docs/KAIRO_AKASH_COORDINATION.md`

---

### Day 3 — Ancestral archive + production payments prep

1. **Pin genesis receipt** to IPFS/Pinata (Council Wishlist `PINATA_JWT`):
   - Upload `dashboard/helix-state.json` + deployed SDL manifest
   - Record CID in Notion hub or `funding/` deck

2. **Sync production branch + Vercel env:**

```bash
./scripts/sync-environment-branches.sh
```

Set live keys per `docs/PRODUCTION_REVENUE_CHECKLIST.md` (Stripe, `SESSION_SECRET`, `APP_URL`).

---

### Day 4 — Agent swarm + referral surfaces

| Stream | Action |
|--------|--------|
| **Swarm Conductor** | Keep agent on `docs/SWARM_CONDUCTOR.md` |
| **MCP** | Load `.cursor/mcp-config-top12.json` into Cursor |
| **Referral** | Enable marketing crons in `crons/marketing-and-shard-harvesting.md` |
| **ValhallA portal** | Production deploy → `/payments`, `/arena`, Kairo rides |

---

### Day 5 — Second revenue rail (Kairo or Stripe)

Pick one to prove conversion:

- **Stripe:** `/payments` → $5 test deposit → webhook `200` in Dashboard
- **Kairo:** `/api/kairo/fare` quote → ride webhook path (1% platform fee)

Log first conversion timestamp for the 30-day retrospective.

---

### Day 6 — Scale decision + Tier A backend (optional)

If Tier B is stable and harmony_index is healthy:

```bash
./scripts/deploy-akash-tier.sh backend   # lightweight API ~$45–75/mo
```

Or add second miner shard: `export AGENT_SHARD_ID=1` and redeploy.

Refs: `docs/AKASH_SDL_BUDGETS.md`

---

### Day 7 — $1 micro-revenue test + Week 1 retrospective

**Micro-test (proves full rail):**

1. Create smallest Stripe Checkout tier ($1 or minimum allowed)
2. Complete payment on production domain
3. Confirm balance credit net of 1% platform fee
4. Snapshot: `helix-state.json`, Arena screenshot, Stripe webhook log

**Alternative micro-test:** Wise/Square $1 deposit if Stripe live keys not ready.

**Week 1 definition of done:**

- [ ] Helix Chain activated (`genesisHash` persisted)
- [ ] Live Akash lease with Vault injection
- [ ] Arena shows real worker telemetry
- [ ] ≥1 payment or Kairo fare conversion logged
- [ ] Ancestral receipt pinned (IPFS CID recorded)
- [ ] `harmony_index` visible in Kairo projection

---

## 4. Days 8–30 (compound)

Full week-by-week plan: **`docs/MULTI_CLOUD_30DAY_PLAN.md`**  
Master checklist: **`docs/30DAY_EXECUTION_CHECKLIST.md`**

| Week | Focus | Key providers |
|------|-------|---------------|
| **2** | GPU scale + Vast burst | Akash + Vast.ai + RunPod |
| **3** | DePIN + training | Salad, Cherry, Azure/GCP Grass |
| **4** | Optimize + extract | Tear down idle burst; document net revenue |

**Week 4 target:** Net positive earnings beyond credit burn; ≥70% credit utilization documented.

---

## 5. GPU rental / marketplace activation

| Phase | Action | Revenue path |
|-------|--------|--------------|
| **List capacity** | Expose worker health on Arena; DePIN marketplace doc | `marketplace/depin-hardware-marketplace.md` |
| **Price GPU hours** | Agent referral engine + Akash worker URLs | Crons + `/arena` |
| **Burst overflow** | Vast.ai when Akash deficit > 0 | `make multicloud-launch` (see multi-cloud branch) |
| **Settle payouts** | Wise treasury + Web3 withdrawals | `docs/PRODUCTION_REVENUE_CHECKLIST.md` |

---

## 6. Daily ops (repeat every morning)

```bash
make akash-preflight          # if lease active
make akash-verify
make status                   # sovereign + monitoring
# When multicloud scripts merged:
# make multicloud-preflight && make multicloud-cost-report
```

---

## 7. Quick refs

| Doc | Purpose |
|-----|---------|
| `TODAY_EXECUTION_PLAN.md` | Day-one P0 human checklist |
| `PRODUCTION_SPINUP.md` | Multi-platform deploy matrix |
| `docs/AKASH_SDL_BUDGETS.md` | Tier A/B/C budgets |
| `docs/MULTI_CLOUD_30DAY_PLAN.md` | Full 30-day provider strategy |
| `docs/30DAY_EXECUTION_CHECKLIST.md` | Phase 0–5 tracker |
| `docs/PRODUCTION_REVENUE_CHECKLIST.md` | Vercel + Stripe wiring |
| `scripts/activate-helix.sh` | Helix / Spheres genesis |
| `docs/HELIX_OMNI_CORE_VIZ_PROMPT.md` | ValhallA visual assets |

---

## 8. Swarm reward protocol

Report back within **48–72 hours** with:

1. Which provider went live first (expected: **Akash Tier B**)
2. `akash-preflight` GO/NO-GO output (redact secrets)
3. `helix-state.json` phase + `genesisHash` prefix
4. First revenue event (Stripe session ID or Kairo fare ID — no PII)

Valid execution updates refine this plan in real time.

**Temper fidelis. Valhalla awaits the yield.**
