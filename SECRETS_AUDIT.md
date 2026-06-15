# SECRETS_AUDIT.md

> Audit date: June 15, 2026

## Summary

**No leaked production API keys** were found in tracked source files. Remaining issues are dev fallbacks and incomplete Vault path coverage.

## Findings

| Severity | Location | Issue | Resolution |
|----------|----------|-------|------------|
| Medium | `src/lib/config/env.ts` | Dev `SESSION_SECRET` fallback | Fail-fast in `NODE_ENV=production` ✅ |
| Medium | `kairo/services/identity.py` | Dev encryption key fallback | Fail-fast with `KAIRO_REQUIRE_ENCRYPTION_KEY=1` ✅ |
| Low | `deploy/monitoring/docker-compose.yml` | Grafana default `yieldswarm` | Set `GRAFANA_PASSWORD` from Vault before prod |
| Low | Test fixtures | Hardhat key in `verify-signature.test.ts` | Acceptable — test only |

## Vault path coverage

| Path | Seeded | Consumed by |
|------|--------|-------------|
| `yieldswarm/akash/runtime` | ✅ | Akash Vault Agent, agents |
| `yieldswarm/odysseus/runtime` | ✅ (added) | Odysseus deploy scripts |
| `yieldswarm/odysseus/deploy` | ✅ (added) | SDL render, GHCR |
| `yieldswarm/payments/runtime` | ✅ (added) | Next.js payments (manual inject) |
| `yieldswarm/kairo/runtime` | ✅ (added) | Kairo identity, Mapbox |
| `yieldswarm/integrations/unstoppable` | ✅ (added) | UD API |
| `yieldswarm/agents/shards/<id>` | ⚠️ Policy only | Per-shard cron overrides |

## Operator actions

1. Rotate any UD API key ever committed to git history
2. Run `SOURCE_ENV=.env vault/setup/05-seed-secrets.sh` on air-gapped workstation
3. Never commit `.env`, `deploy/config.env`, or `*.tfvars`
4. Enable `NETWORK_LOCKDOWN_MODE=true` in production Akash SDL

## Pre-merge grep (run before each release)

```bash
git grep -nE '(ghp_|sk_live_|sk_test_|ud_mcp_[a-f0-9]{20,})' -- ':!*.example' ':!SECRETS_AUDIT.md'
```

Expected: no matches.
