# MERGE_STRATEGY.md — Consolidate `cursor/*` → Clean `main`

**Branch:** `cursor/god-prompt-full-system-597f`  
**Date:** 2026-06-15  
**Status:** Ready for review

---

## 1. Target branch ladder

After consolidation, create and protect these branches from `main`:

```bash
git checkout main && git pull origin main
for branch in development testnet devnets production MAINNET; do
  git branch -f "$branch" main
  git push -u origin "$branch"
done
```

| Branch | Deploy target | Merge policy |
|--------|---------------|--------------|
| `main` | Vercel preview + CI | PR required |
| `development` | Vercel dev | PR from `main` |
| `testnet` | Akash testnet | Fast-forward from `development` |
| `devnets` | 1-shard Akash soak | Fast-forward from `testnet` |
| `production` | Akash prod + fallback | 2 approvals |
| `MAINNET` | Live contracts + MAINNET RPC | 2 approvals + admin |

---

## 2. Canonical branch map (56 → 1)

This PR (`cursor/god-prompt-full-system-597f`) supersedes the following branches.
**Close duplicate PRs** after merge; delete branches in Section 5.

| Area | Canonical source | Merged into this PR |
|------|------------------|---------------------|
| Helix foundation | `cursor/helix-chain-activation-597f` | ✅ base |
| Akash SDL + deploy | `cursor/harden-akash-sdl-worker-ff04` | ✅ |
| Akash lease manager | `cursor/akash-lease-manager-f88c` | ✅ |
| Deploy orchestrator | `cursor/production-deploy-orchestrator-85ce` | ✅ |
| Vault integration | `cursor/complete-vault-integration-82c9` | ✅ |
| Multi-cloud Terraform | `cursor/multicloud-fallback-infra-e3ca` | ✅ |
| Domains | `cursor/wire-unstoppable-domains-ffe8` | ✅ |
| Odysseus deploy | `cursor/add-odysseus-deployments-edbd` | ✅ |
| Odysseus memory | `cursor/odysseus-chromadb-memory-d634` | ✅ |
| Odysseus tools | `cursor/yieldswarm-odysseus-tools-3c2a` | ✅ |
| Odysseus UI | `cursor/odysseus-ui-integration-35ff` | ✅ |
| Payment rails | `cursor/build-payment-rails-5087` | ✅ |
| Unified wallet | `cursor/unified-wallet-system-690e` | ✅ |
| Sovereign core | `cursor/iteration-100-sovereign-core-fede` | ✅ |
| Emission router | `cursor/greatdelta-emission-router-1068` | ✅ |
| Arena system | `cursor/agents-arena-system-21fb` | ✅ |
| Kairo + God prompt | `cursor/god-prompt-full-system-597f` | ✅ (this branch) |

### Duplicates to close (do not merge)

```text
cursor/vault-integration-*          (×24)  → superseded by complete-vault-integration
cursor/hashicorp-vault-integration-* (×5)  → superseded
cursor/multicloud-fallback-6923              → superseded by multicloud-fallback-infra-e3ca
cursor/great-delta-emission-router-4594      → superseded by greatdelta-emission-router-1068
cursor/iteration-100-sovereign-loops-6c60   → superseded by iteration-100-sovereign-core-fede
cursor/integrate-odysseus-1074             → superseded by odysseus-ui + deployments
```

---

## 3. Merge priority order

Execute in this sequence to respect dependencies:

```bash
# Step 0 — merge this PR (all 16 prongs consolidated)
gh pr merge cursor/god-prompt-full-system-597f --squash

# Step 1 — create track branches
git checkout main && git pull
for b in development testnet devnets production MAINNET; do
  git branch "$b" main && git push -u origin "$b"
done

# Step 2 — tag foundation
git tag -a v1.0-helix-launch -m "God prompt: 16-prong consolidation"
git push origin v1.0-helix-launch
```

No further `cursor/*` merges are required after this PR unless new feature work begins.

---

## 4. Conflict resolution rules

| Conflict type | Resolution |
|---------------|------------|
| Duplicate `deploy/` SDLs | Keep `deploy/deploy-swarm-monolith.yaml` (3× RTX 3090); Odysseus uses `deploy/akash/odysseus.sdl.yml` |
| Duplicate `terraform/` roots | `infra/terraform/` = multi-cloud fallback; `terraform/` = Vault-backed providers; `terraform/odysseus/` = Odysseus-specific |
| Duplicate frontends | `src/` = Next.js payments (Vercel); `frontend/` = Vite wallet/arena (Vercel or Netlify); `kairo/frontend/` = Kairo ride app |
| Secrets | Vault only — never merge plaintext keys from `.env.example` variants |

---

## 5. Post-merge branch cleanup

After PR merge and smoke tests pass:

```bash
# List merged cursor branches
git branch -r | grep 'origin/cursor/' | sed 's|origin/||' > /tmp/cursor-branches.txt

# Delete each (requires admin)
while read -r branch; do
  gh api -X DELETE "repos/Yield-Swarm/yieldswarm-agent-swarm-v2/git/refs/heads/${branch#origin/}" 2>/dev/null \
    || git push origin --delete "${branch#origin/}"
done < /tmp/cursor-branches.txt
```

Close open draft PRs #1–#23 on GitHub (superseded by this consolidation PR).

---

## 6. Verification after merge

```bash
./scripts/smoke-test.sh
make preflight
python -m pytest tests/ -q
cd frontend && npm ci && npm run typecheck
cd kairo && pip install -r requirements.txt && python -m pytest tests/ -q
```

All checks must pass before promoting `main` → `development`.
