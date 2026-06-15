# PRODUCTION_READINESS.md

> Generated: June 15, 2026 — God Prompt integration pass

## Overall: **STAGING READY** (not MAINNET)

The monorepo is deployable to Akash + Vercel with Vault-backed secrets. On-chain emission router and full auth are not yet production-hardened.

## Checklist

| Area | Ready | Blocker |
|------|-------|---------|
| `main` branch integration | ⚠️ | Merge `cursor/mega-round-integration-e512` → `main` |
| HashiCorp Vault bootstrap | ✅ | Run `vault/setup/bootstrap.sh` on target cluster |
| Akash deploy | ✅ | Funded wallet + `make deploy` |
| Odysseus GPU stack | ⚠️ | Vault secrets + RTX 3090 lease |
| Kairo API + frontend | ✅ | Set `MAPBOX_TOKEN`, deploy to Vercel |
| Payment rails | ⚠️ | Square/Wise prod keys in Vault |
| Arena telemetry | ✅ | `/api/telemetry/*` wired |
| $5M vault dashboard | ✅ | `/vault-dashboard` + live overlay API |
| Sovereign loops | ⚠️ | Simulation data; wire live Akash/treasury feeds |
| Great Delta router | ❌ | Foundry tests + mainnet deploy |
| Secrets hygiene | ⚠️ | See `SECRETS_AUDIT.md` |
| Branch protection | ❌ | Enable on GitHub |

## Pre-deploy commands

```bash
make preflight
vault/setup/bootstrap.sh
source scripts/lib/vault-env.sh && vault_export_env kv/data/yieldswarm/akash/runtime
make deploy
scripts/deploy-production-odysseus.sh akash
./scripts/smoke-test.sh
```

## Post-deploy verification

```bash
curl -fsS https://<worker>/healthz
curl -fsS http://localhost:8080/api/health
curl -fsS http://localhost:8080/api/vault/telemetry | jq .progress
curl -fsS http://localhost:8080/api/telemetry/akash | jq .workers
```

## Environment promotion

```
development → testnet → production → MAINNET
```

See `MERGE_STRATEGY.md` for branch rules.

## Risk register

| Risk | Mitigation |
|------|------------|
| Duplicate Vault PRs merged accidentally | Close without merge; use integration branch only |
| Dev session secret in production | `SESSION_SECRET` now fails fast in production |
| Grafana default password | Set `GRAFANA_PASSWORD` in Vault before exposing monitoring |
| Two GreatDelta contracts | Consolidate before mainnet (see `contracts/quadrant-iv/`) |
