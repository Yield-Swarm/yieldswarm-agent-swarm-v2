# Branch Strategy — YieldSwarm / Kairo Helix Chain

Deployment-track branches for the AgentSwarm OS. Feature work lands on `main`
via PR; tracks are long-lived promotion lanes.

---

## Branch ladder

```
feature/cursor/*  ──PR──►  main  ──promote──►  development
                                                  │
                                                  ▼
                                               testnet
                                                  │
                                                  ▼
                                               devnets
                                                  │
                                                  ▼
                                              production
                                                  │
                                                  ▼
                                               MAINNET
```

| Branch | Purpose | Deploy target | Protection |
|--------|---------|---------------|------------|
| `main` | Integration / PR target | Vercel preview | Require PR + CI |
| `development` | Active dev integration | Vercel dev | Require PR |
| `testnet` | Public testnet contracts + agents | Akash testnet leases | Require PR + review |
| `devnets` | Multi-devnet sharded crons | Akash + fallback (1 shard) | Require PR + review |
| `production` | Staging production | Akash prod + multi-cloud | Require 2 reviews |
| `MAINNET` | Live mainnet | Akash prod + MAINNET RPC | Require 2 reviews + admin |

---

## Promotion flow

1. Merge feature PRs into `main` (squash recommended).
2. When `main` is green (`make preflight` + smoke tests), fast-forward `development`.
3. Promote `development` → `testnet` after testnet contract deploy succeeds.
4. Promote `testnet` → `devnets` after 1-shard cron soak (24h).
5. Promote `devnets` → `production` after full Akash lease + Vault audit.
6. Promote `production` → `MAINNET` after council DAO sign-off.

```bash
# Example: promote main → development
git checkout development
git merge --ff-only main
git push origin development
```

---

## `cursor/*` branch cleanup

56 agent branches exist. Consolidate before merging:

| Feature area | Canonical branch | Duplicates to close |
|--------------|------------------|---------------------|
| Vault / secrets | `cursor/complete-vault-integration-82c9` | ~30 `cursor/vault-integration-*` |
| Akash deploy | `cursor/harden-akash-sdl-worker-ff04` | — |
| Akash lease manager | `cursor/akash-lease-manager-f88c` | — |
| Multi-cloud Terraform | `cursor/multicloud-fallback-infra-e3ca` | `cursor/multicloud-fallback-6923` |
| Deploy orchestrator | `cursor/production-deploy-orchestrator-85ce` | — |
| Domains | `cursor/wire-unstoppable-domains-ffe8` | — |
| Odysseus | `cursor/odysseus-ui-integration-35ff` | `cursor/integrate-odysseus-1074` |
| Emission router | `cursor/greatdelta-emission-router-1068` | `cursor/great-delta-emission-router-4594` |
| Sovereign core | `cursor/iteration-100-sovereign-core-fede` | `cursor/iteration-100-sovereign-loops-6c60` |

**This PR** (`cursor/helix-chain-activation-597f`) consolidates infra, domains,
Vault, Akash, and Terraform into one merge-ready branch.

### Merge order (dependency-first)

1. `cursor/helix-chain-activation-597f` — infra foundation (this PR)
2. Vault runtime + `SECRETS.md` validation
3. Akash lease manager + monolith SDL
4. Odysseus tools → memory → UI → deployments
5. Arena / telemetry dashboards
6. Payments / wallet / emission router
7. Sovereign core / production orchestrator

### Delete stale branches (after merge)

```bash
# After PR merges, delete consolidated cursor branches
for b in $(git branch -r | grep 'origin/cursor/vault-integration-' | sed 's|origin/||'); do
  git push origin --delete "$b"
done
```

---

## Tags & milestones

| Tag / branch | When |
|--------------|------|
| `v1.0-helix-launch` | First successful Akash deploy + domains wired |
| `milestone/helix-chain-activation` | Celebration branch after launch |

```bash
git tag -a v1.0-helix-launch -m "Helix Chain activation: Akash + domains live"
git push origin v1.0-helix-launch
git checkout -b milestone/helix-chain-activation
```

---

## Kairo placement

Kairo lives in **`/kairo`** within this repo for now (shared Vault, Akash, and
domain wiring). Extract to a separate repo when the UI stabilizes; until then,
`/kairo` references YieldSwarm infra via `../deploy/` and `../akash/`.
