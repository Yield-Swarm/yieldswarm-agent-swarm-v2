# Production Readiness Report

> God Prompt Prong 16 — Final integration pass · June 15, 2026

## Overall: STAGING READY

The system is deployable from a clean `main` branch with operator credentials. Live mainnet requires funded Akash wallet, Vault cluster, and domain DNS.

---

## Component Readiness

| Component | Ready | Blocker |
|-----------|-------|---------|
| Git merge / branches | ✅ | Close duplicate Vault PRs |
| Vault bootstrap | ✅ | Operator runs `vault/setup/bootstrap.sh` |
| Akash deploy (Vault) | ✅ | Funded wallet + `VAULT_TOKEN` |
| Akash deploy (legacy) | ✅ | `make akash-lease` works without Vault |
| Odysseus local stack | ✅ | `docker compose -f docker-compose.yml -f docker-compose.odysseus.yml up` |
| Odysseus production | ⚠️ | Swap health stub for upstream Odysseus image |
| Kairo identity | ✅ | `python3 kairo/cli.py register` |
| Kairo frontend | ⚠️ | `VITE_MAPBOX_TOKEN` required |
| Payment rails | ✅ | Square/Wise env vars + webhook URLs |
| $5M dashboard | ⚠️ | Run `python3 iteration-100/run.py` to refresh `dashboard/state.json` |
| Arena live metrics | ✅ | Backend `:8787` + `frontend/src/routes/Arena.tsx` |
| Multi-cloud Terraform | ✅ | Choose canonical tree: `infra/terraform/` for deficit scaling |
| Emission router | ⚠️ | Deploy contract + set `GD_ROUTER_ADDRESS` |
| Secrets hygiene | ✅ | `scripts/secrets-audit.sh` passes |
| CI pipeline | ✅ | `.github/workflows/ci.yml` |

---

## Smoke Test Commands

```bash
bash scripts/secrets-audit.sh
bash scripts/pre-merge-audit.sh
python3 tests/test_smoke_integration.py
cd backend && npm test
curl -s http://localhost:8787/api/health | jq .
curl -s http://localhost:8787/api/kairo/health | jq .
curl -s http://localhost:8787/api/sovereign/overview | jq .
curl -s http://localhost:8787/api/arena/overview | jq .
```

---

## Broken Connections Fixed This Pass

| Issue | Fix |
|-------|-----|
| Vault deploy disconnected from orchestrator | `deploy/scripts/akash-production-deploy.sh` + `USE_VAULT_AKASH=1` |
| Arena React not wired to backend | `frontend/src/routes/Arena.tsx` → `/api/arena/overview` |
| No Kairo frontend | `kairo/app/` Vite + Mapbox scaffold |
| No sovereign API | `GET /api/sovereign/overview` + SSE stream |
| Odysseus health-only stub | Expanded orchestrator status + upstream pings |
| No CI / secret scan | `.github/workflows/ci.yml`, `secrets-scan.yml` |
| Missing docs | `INTEGRATION_REPORT.md`, `KAIRO_FRONTEND.md`, this file |

---

## Pre-Mainnet Checklist

- [ ] Vault HA cluster operational (5-node Raft per `SECRETS.md`)
- [ ] Akash lease live with RTX 3090 workers
- [ ] Odysseus full image deployed (not health stub)
- [ ] `api.<domain>` DNS pointed and TLS valid
- [ ] Square/Wise webhooks registered to production URLs
- [ ] Great Delta router deployed; duplicate contract removed
- [ ] `dashboard/state.json` fed by live sovereign daemon
- [ ] Branch protection enabled on `main` and `MAINNET`

---

## Recommended Deploy Order

1. Vault bootstrap + seed secrets
2. `make build` (GHCR images)
3. `USE_VAULT_AKASH=1 make akash-deploy-vault`
4. `docker compose -f docker-compose.yml -f docker-compose.odysseus.yml up -d` (or Akash Odysseus SDL)
5. `cd backend && npm start`
6. Vercel deploy Kairo app (`vercel --prod`)
7. Wire domains per `DOMAINS.md`
8. `make monitoring-up sovereign-up`
