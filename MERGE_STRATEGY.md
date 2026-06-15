# YieldSwarm Merge + Branch Strategy

## Current State (2026-06-15)

| Branch | Status | Notes |
|--------|--------|-------|
| `main` | Clean baseline | Initial commit `576a329` — AgentSwarm OS v2.0 scaffold |
| `cursor/*` | None pending | No open feature branches to consolidate |
| `cursor/mega-task-consolidation-5049` | Active | This mega-task delivery branch |

All `cursor/*` work from this session lands on `cursor/mega-task-consolidation-5049` and merges to `main` via PR.

---

## Target Branch Structure

```
main          ← stable documentation + shared contracts (protected)
├── development   ← daily integration, all feature PRs merge here first
├── testnet       ← staged releases with testnet RPCs + sandbox keys
├── devnets       ← per-shard devnet configs (84-agent shards)
├── production    ← pre-mainnet staging (Akash leases, Vault, real $)
└── MAINNET       ← production mainnet cutover (protected, tag-only deploys)
```

### Branch Policies

| Branch | Merge From | Deploy Target | Protection |
|--------|-----------|---------------|------------|
| `development` | `cursor/*`, `main` | Local / Codespaces | Require PR, 1 review |
| `testnet` | `development` | Vercel preview + testnet RPCs | Require PR, CI green |
| `devnets` | `testnet` | Per-shard Akash dev leases | Require PR |
| `production` | `devnets` | Akash production leases + Vault | Require PR, 2 reviews |
| `MAINNET` | `production` | Mainnet wallets, real treasury | Require PR, 2 reviews + manual approval |
| `main` | `MAINNET` (cherry-pick docs only) | Documentation sync | Protected |

---

## Recommended Commands

### 1. Create branch structure from `main`

```bash
git checkout main
git pull origin main

# Create long-lived branches
for branch in development testnet devnets production MAINNET; do
  git checkout -b "$branch" main
  git push -u origin "$branch"
done

git checkout main
```

### 2. Merge this mega-task branch

```bash
# After PR approval on cursor/mega-task-consolidation-5049
git checkout development
git pull origin development
git merge --no-ff origin/cursor/mega-task-consolidation-5049 \
  -m "feat: mega-task consolidation — Akash, Kairo, Odysseus, payments, domains"

# Run smoke tests
./scripts/health-check.sh --env development || true

git push origin development
```

### 3. Promote through environments

```bash
# development → testnet
git checkout testnet && git pull origin testnet
git merge --no-ff origin/development -m "promote: development → testnet"
git push origin testnet

# testnet → devnets
git checkout devnets && git pull origin devnets
git merge --no-ff origin/testnet -m "promote: testnet → devnets"
git push origin devnets

# devnets → production
git checkout production && git pull origin production
git merge --no-ff origin/devnets -m "promote: devnets → production"
git push origin production

# production → MAINNET (tagged release)
git checkout MAINNET && git pull origin MAINNET
git merge --no-ff origin/production -m "release: production → MAINNET"
git tag -a "v2.0.0-mainnet" -m "YieldSwarm AgentSwarm OS v2.0 mainnet"
git push origin MAINNET --tags
```

### 4. Sync documentation back to `main`

```bash
git checkout main
git cherry-pick <docs-only-commits>   # README, DEPLOY.md, DOMAINS.md, MERGE_STRATEGY.md
git push origin main
```

---

## Conflict Resolution Guidelines

1. **`.env` / secrets** — Never merge. Each branch uses Vault or environment-specific secrets.
2. **`deploy/*.yaml`** — Branch-specific overrides via `env:` blocks; base manifest stays identical.
3. **`services/`** — Feature branches win on new code; `development` resolves cross-service conflicts.
4. **Documentation** — Latest wins; reconcile manually if both branches edited the same section.

---

## GitHub Branch Protection (Recommended)

```yaml
# .github/branch-protection.yml (apply via GitHub Settings → Branches)
main:
  required_reviews: 1
  require_signed_commits: true
MAINNET:
  required_reviews: 2
  required_status_checks: [ci, vault-smoke, akash-health]
production:
  required_reviews: 2
  required_status_checks: [ci, vault-smoke]
```

---

## Consolidating Future `cursor/*` Branches

When multiple `cursor/*` branches exist:

```bash
# List all cursor branches
git branch -r | grep 'origin/cursor/'

# Merge in dependency order (infra → identity → integrations → polish)
for branch in \
  cursor/akash-vault-deploy-5049 \
  cursor/kairo-identity-5049 \
  cursor/odysseus-integration-5049 \
  cursor/payment-rails-5049 \
  cursor/domains-config-5049; do
  git checkout development
  git merge --no-ff "origin/$branch" -m "merge: $branch into development" || {
    echo "CONFLICT on $branch — resolve, then: git merge --continue"
    exit 1
  }
done
git push origin development
```

---

## Rollback

```bash
# Revert a bad promotion
git checkout production
git revert -m 1 HEAD
git push origin production

# Emergency MAINNET rollback — redeploy previous tag
git checkout MAINNET
git checkout tags/v2.0.0-mainnet~1   # previous tag
./scripts/akash-deploy.sh --rollback
```
