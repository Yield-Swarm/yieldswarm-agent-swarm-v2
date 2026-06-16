#!/usr/bin/env bash
# Merge all open cursor/* PR branches into production (async batch).
#
# Usage:
#   ./scripts/merge-all-prs-to-production.sh --dry-run
#   ./scripts/merge-all-prs-to-production.sh --push
#   ./scripts/merge-all-prs-to-production.sh --push --sync-env
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=0
PUSH=0
SYNC_ENV=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --push) PUSH=1; shift ;;
    --sync-env) SYNC_ENV=1; shift ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

log() { echo "[merge-production] $*"; }
die() { log "ERROR: $*"; exit 1; }

MERGE_BRANCHES=(
  cursor/god-prompt-swarm-9c82
  cursor/sovereign-loops-live-9c82
  cursor/akash-real-deploy-9c82
  cursor/kairo-akash-parallel-9c82
  cursor/tesla-fleet-integration-9c82
  cursor/multi-cloud-30day-plan-9c82
  cursor/final-deployment-orchestrator-9c82
  cursor/cross-chain-execution-9c82
  cursor/cloud-scheduler-30day-9c82
)

branch_exists() {
  git show-ref --verify --quiet "refs/remotes/origin/$1"
}

commits_ahead() {
  local base="$1" head="$2"
  git rev-list --count "${base}..${head}" 2>/dev/null || echo 0
}

merge_into_production() {
  local src="$1"
  local msg="$2"

  if ! branch_exists "${src}"; then
    log "SKIP ${src} (missing on origin)"
    return 0
  fi

  local tip
  tip="$(git rev-parse HEAD)"
  local ahead
  ahead="$(commits_ahead "${tip}" "origin/${src}")"
  if [[ "${ahead}" -eq 0 ]]; then
    log "SKIP ${src} (already contained in production)"
    return 0
  fi

  log "PLAN: merge origin/${src} (+${ahead} commits)"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi

  if ! git merge --no-ff "origin/${src}" -m "${msg}"; then
    die "merge conflict on ${src} — resolve and re-run"
  fi
  log "OK merged ${src}"
}

preflight() {
  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree dirty"
  fi
}

main() {
  log "Async merge all open PR branches → production"
  [[ "${DRY_RUN}" -eq 1 ]] || preflight

  git fetch origin --prune

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "production tip: $(git rev-parse --short HEAD)"
    log "main tip:       $(git rev-parse --short origin/main)"
    for b in "${MERGE_BRANCHES[@]}"; do
      if branch_exists "$b"; then
        ahead="$(commits_ahead HEAD "origin/$b")"
        log "  ${b}: ${ahead} commits ahead of production"
      fi
    done
    return 0
  fi

  git checkout production
  git pull origin production

  log "Step 1: sync production ← main (if needed)"
  local main_ahead
  main_ahead="$(commits_ahead HEAD origin/main)"
  if [[ "${main_ahead}" -gt 0 ]]; then
    git merge --no-ff origin/main -m "promote: sync production with main" || die "main merge conflict"
  fi

  log "Step 2: merge open PR branches"
  for b in "${MERGE_BRANCHES[@]}"; do
    merge_into_production "${b}" "Merge ${b} into production (async PR batch)"
  done

  if [[ "${PUSH}" -eq 1 ]]; then
    log "Step 3: push production"
    git push origin production

    if [[ "${SYNC_ENV}" -eq 1 ]]; then
      log "Step 4: sync environment branches to production tip"
      local tip
      tip="$(git rev-parse HEAD)"
      for env in main testnet devnets development MAINNET; do
        if git show-ref --verify --quiet "refs/remotes/origin/${env}"; then
          git branch -f "${env}" "${tip}"
          git push --force-with-lease origin "${env}" || git push origin "${env}"
          log "  synced ${env}"
        fi
      done
    fi
  else
    log "Local merges complete — re-run with --push to publish"
  fi

  log "Done. production tip: $(git rev-parse --short HEAD)"
}

main "$@"
