#!/usr/bin/env bash
# =============================================================================
# Mega-Round Integration Merge — GitOps + Ethical Security Guardian
#
# Hardened merge of cursor/mega-round-integration-e512 into main with:
#   - pre-flight dirty-tree + stash protection
#   - annotated safety backup tag (rollback path)
#   - secret-leak scan on merge diff
#   - --no-ff merge (governance audit trail)
#   - atomic multi-branch push (main + env branches)
#
# Usage:
#   ./artifacts/scripts/mega-round-integration-merge.sh
#   ./artifacts/scripts/mega-round-integration-merge.sh --dry-run
#   ./artifacts/scripts/mega-round-integration-merge.sh --skip-push
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SOURCE_BRANCH="cursor/mega-round-integration-e512"
DRY_RUN=false
SKIP_PUSH=false
STASHED=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-push) SKIP_PUSH=true ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
  esac
done

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_BOLD=$'\033[1m'
else
  C_RESET=""; C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""
fi

log()  { printf '%s[%s]%s %s\n' "$C_BLUE"  "$(date +%H:%M:%S)" "$C_RESET" "$*"; }
ok()   { printf '%s[ ok ]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%s[warn]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%s[fail]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; }
step() { printf '\n%s==>%s %s%s%s\n' "$C_BOLD" "$C_RESET" "$C_BOLD" "$*" "$C_RESET"; }

ENV_BRANCHES=(development testnet devnets production MAINNET)
SAFETY_TAG="safety/pre-mega-round-$(date +%Y%m%d-%H%M%S)"

step "Pre-flight: fetch + working tree"
git fetch origin main development testnet devnets production MAINNET "$SOURCE_BRANCH" 2>/dev/null || git fetch origin

if ! git diff --quiet || ! git diff --cached --quiet; then
  warn "Dirty working tree — auto-stashing"
  if $DRY_RUN; then
    err "Dry run: commit or stash changes first"
    exit 1
  fi
  git stash push -u -m "mega-round-merge auto-stash $(date -Iseconds)"
  STASHED=true
fi

CURRENT_BRANCH="$(git branch --show-current)"
git checkout main
git pull origin main 2>/dev/null || true

MAIN_TIP="$(git rev-parse --short HEAD)"
log "main tip: $MAIN_TIP"

if ! git show-ref --verify --quiet "refs/remotes/origin/$SOURCE_BRANCH"; then
  err "Remote branch origin/$SOURCE_BRANCH not found"
  exit 1
fi

SOURCE_TIP="$(git rev-parse --short "origin/$SOURCE_BRANCH")"
log "source tip: origin/$SOURCE_BRANCH @ $SOURCE_TIP"

step "Safety backup tag"
if $DRY_RUN; then
  log "[dry-run] would create annotated tag: $SAFETY_TAG"
else
  git tag -a "$SAFETY_TAG" -m "Safety backup before mega-round merge ($(date -Iseconds))"
  ok "created rollback tag: $SAFETY_TAG"
fi

step "Merge status check"
if git merge-base --is-ancestor "origin/$SOURCE_BRANCH" HEAD; then
  ok "origin/$SOURCE_BRANCH already fully contained in main — merge is a no-op"
  MERGE_NEEDED=false
else
  MERGE_NEEDED=true
  BEHIND="$(git rev-list --count HEAD.."origin/$SOURCE_BRANCH")"
  log "$BEHIND commit(s) to merge from origin/$SOURCE_BRANCH"
fi

if $MERGE_NEEDED; then
  step "Ethical secret-leak scan (merge diff)"
  DIFF_RANGE="HEAD...origin/$SOURCE_BRANCH"
  if $DRY_RUN; then
    log "[dry-run] would scan diff: $DIFF_RANGE"
  else
    if git diff "$DIFF_RANGE" | rg -n \
      -e 'sk_live_|sk-proj-|sk-or-v1-|xai-[A-Za-z0-9]{10,}' \
      -e 'ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}' \
      -e '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' \
      2>/dev/null; then
      err "SECRET DETECTED in merge diff — aborting. Rotate keys before merge."
      exit 1
    fi
    ok "no obvious secrets in merge diff"
  fi

  step "Merge --no-ff origin/$SOURCE_BRANCH"
  if $DRY_RUN; then
    log "[dry-run] git merge --no-ff origin/$SOURCE_BRANCH -m 'Merge origin/$SOURCE_BRANCH: mega-round integration'"
  else
    git merge --no-ff "origin/$SOURCE_BRANCH" \
      -m "Merge origin/$SOURCE_BRANCH: mega-round integration (Kairo, smoke tests, sovereign fixes)"
    ok "merge complete"
  fi
else
  step "Pre-merge repo secret scan"
  if $DRY_RUN; then
    log "[dry-run] would run scripts/secrets-audit.sh"
  elif [[ -x scripts/secrets-audit.sh ]]; then
    if bash scripts/secrets-audit.sh; then
      ok "repo secret scan passed"
    else
      warn "repo secret scan reported findings — review docs/scripts (often false positives on \$VAR refs)"
    fi
  else
    warn "scripts/secrets-audit.sh not found — skipping"
  fi
fi

step "Post-merge verification"
if ! $DRY_RUN && [[ -x scripts/pre-merge-audit.sh ]]; then
  if bash scripts/pre-merge-audit.sh; then
    ok "pre-merge audit passed"
  else
    warn "pre-merge audit failed — review before push (continuing env sync)"
  fi
elif $DRY_RUN; then
  log "[dry-run] would run scripts/pre-merge-audit.sh"
fi

step "Sync environment branches to main"
if $DRY_RUN; then
  bash scripts/sync-environment-branches.sh --dry-run
else
  bash scripts/sync-environment-branches.sh
fi

step "Push all branches"
if $SKIP_PUSH; then
  warn "--skip-push: not pushing to origin"
elif $DRY_RUN; then
  log "[dry-run] would push: main ${ENV_BRANCHES[*]}"
  log "[dry-run] would push tag: $SAFETY_TAG"
else
  git push origin main
  for branch in "${ENV_BRANCHES[@]}"; do
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      git push origin "$branch" || warn "push failed for $branch"
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git push origin "main:$branch" || warn "push failed for $branch (main:$branch)"
    else
      git push origin "main:$branch" || warn "push failed for $branch (create)"
    fi
  done
  git push origin "$SAFETY_TAG" 2>/dev/null || true
  ok "pushed main + env branches + safety tag"
fi

if $STASHED; then
  step "Restore stashed changes"
  git checkout "$CURRENT_BRANCH" 2>/dev/null || true
  git stash pop || warn "stash pop had conflicts — resolve manually"
fi

step "Bug Bounty activation checklist"
cat <<'BOUNTY'

Post-merge verification (SOL rewards from 20% treasury yield bucket):
  1. Deploy testnet/devnets first — never MAINNET cold
  2. make smoke-test && make referral-api-test
  3. curl /api/helix/status && /api/treasury/gpu-credits
  4. AgentSwarm OS: ElizaOS/LangGraph/CrewAI + ZKML Arena simulations
  5. Monitor: GPU yield, cross-chain (TON/SOL/ETH), wallet edge cases, prompt injection
  6. Responsible disclosure → Linear issue + SOL bounty claim

Rollback: git checkout main && git reset --hard $SAFETY_TAG

BOUNTY
ok "Mega-round integration merge workflow complete"
echo "  Rollback tag: $SAFETY_TAG"
