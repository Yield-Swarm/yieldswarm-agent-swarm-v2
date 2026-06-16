# Today's Execution Plan — June 15, 2026

One-page checklist: **human steps first**, then agent swarm in parallel.

---

## P0 — Human (blocks live Akash revenue)

| Step | Action | Done |
|------|--------|------|
| 1 | Export Vault token (never commit): `export VAULT_ADDR=https://vault.yieldswarm.io:8200` + `export VAULT_TOKEN=...` | [ ] |
| 2 | Set shard: `export AGENT_SHARD_ID=0` | [ ] |
| 3 | Fund Akash wallet **≥ 0.5 AKT** to `yieldswarm-admin` (or key in `deploy/akash.env`) | [ ] |
| 4 | Run preflight — must say **GO**: `make akash-preflight` | [ ] |
| 5 | Live deploy europlots: `make deploy-akash-europlots` | [ ] |
| 6 | Verify lease: `make akash-verify` | [ ] |
| 7 | Wire Arena: `source .run/akash-lease.env` → open `/arena?workers=${AKASH_WORKER_URLS}` | [ ] |

### Copy-paste block (after wallet funded)

```bash
export VAULT_ADDR=https://vault.yieldswarm.io:8200
export VAULT_TOKEN=<your-token>
export AGENT_SHARD_ID=0

make akash-preflight          # must be GO
make deploy-akash-europlots
make akash-verify
source .run/akash-lease.env
echo "Arena: /arena?workers=${AKASH_WORKER_URLS}"
```

---

## P1 — Agent swarm (parallel, after P0 or while waiting on human)

| Stream | Task | Branch / PR | Owner |
|--------|------|-------------|-------|
| **Conductor** | Keep Swarm Conductor agent open; enforce merge order | — | Meta-agent |
| **Merge** | vault → production-prep (#25) → god-prompt (#27) → akash-real (#28) → sovereign-loops | `cursor/*-9c82` | Merge agent |
| **MCP** | Load `.cursor/mcp-config-top12.json` into Cursor | `cursor/god-prompt-swarm-9c82` | Agent |
| **Funding** | Review `funding/` with counsel; expand deck if needed | `funding/` | Human + Agent |
| **F — Scale** | Multi-worker Akash pools + `make scale-akash-workers` | new branch | Agent |
| **G — Postgres** | Payments persistence (Neon) | new branch | Agent |
| **H — Sovereign** | `sovereign_runtime.py` metrics + alerts | `cursor/sovereign-loops-live-9c82` | Agent |

---

## Merge order (do not skip)

```
vault-akash-injection → production-prep → god-prompt-swarm → akash-real-deploy → sovereign-loops-live → main
```

---

## Swarm Conductor

Keep a dedicated Cursor agent running `docs/SWARM_CONDUCTOR.md`. It coordinates parallel agents and surfaces blockers (wallet, Vault token, preflight NO-GO).

---

## Definition of done (today)

- [ ] Live Akash lease on **provider.europlots.com** with Vault injection
- [ ] `make akash-verify` → GO
- [ ] Arena shows real worker telemetry
- [ ] PR #28 merged (or stacked after #25–#27)
- [ ] Funding folder reviewed (not sent to investors without counsel)

---

## Quick refs

| Doc | Purpose |
|-----|---------|
| `docs/AKASH_DEPLOY.md` | Full deploy guide |
| `docs/AKASH_DEPLOY_WAVE_COORDINATION.md` | Akash wave A–E rules |
| `docs/SWARM_CONDUCTOR.md` | Meta-agent prompt |
| `docs/VAULT_AKASH_RUNTIME.md` | Vault → container injection |
| `funding/` | Raise materials ($5–20M) |
