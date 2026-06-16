#!/usr/bin/env bash
# =============================================================================
# merge-all-prs.sh — Safe stacked PR merge for YieldSwarm cursor/*-9c82 branches
#
# Usage:
#   ./scripts/merge-all-prs.sh --dry-run          # show plan only
#   ./scripts/merge-all-prs.sh                      # local merges only (no push)
#   ./scripts/merge-all-prs.sh --push               # merge locally + push main
#   ./scripts/merge-all-prs.sh --include-optional   # also merge kairo/tesla/multicloud
#
# Merge order (critical — do not reorder):
#   1. vault-akash-injection → production-prep
#   2. production-prep → main
#   3. god-prompt-swarm → main
#   4. sovereign-loops-live → main
#   5. akash-real-deploy → main
#   [optional] kairo-akash-parallel, tesla-fleet-integration, multi-cloud-30day-plan
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

DRY_RUN=0
PUSH=0
INCLUDE_OPTIONAL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --push) PUSH=1; shift ;;
    --include-optional) INCLUDE_OPTIONAL=1; shift ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

log() { echo "[merge-all-prs] $*"; }
die() { log "ERROR: $*"; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "required: $1"; }

need_cmd git

# Branch names (remote tracking)
VAULT_BRANCH="cursor/vault-akash-injection-9c82"
PROD_BRANCH="cursor/production-prep-9c82"
GOD_BRANCH="cursor/god-prompt-swarm-9c82"
SOV_BRANCH="cursor/sovereign-loops-live-9c82"
AKASH_BRANCH="cursor/akash-real-deploy-9c82"
KAIRO_BRANCH="cursor/kairo-akash-parallel-9c82"
TESLA_BRANCH="cursor/tesla-fleet-integration-9c82"
MULTI_BRANCH="cursor/multi-cloud-30day-plan-9c82"

CORE_MERGES=(
  "${VAULT_BRANCH}→${PROD_BRANCH}"
  "${PROD_BRANCH}→main"
  "${GOD_BRANCH}→main"
  "${SOV_BRANCH}→main"
  "${AKASH_BRANCH}→main"
)

OPTIONAL_MERGES=(
  "${KAIRO_BRANCH}→main"
  "${TESLA_BRANCH}→main"
  "${MULTI_BRANCH}→main"
)

fetch_all() {
  log "fetching origin..."
  git fetch origin --prune
}

branch_exists() {
  git show-ref --verify --quiet "refs/remotes/origin/$1"
}

commits_ahead() {
  local base="$1" head="$2"
  git rev-list --count "origin/${base}..origin/${head}" 2>/dev/null || echo 0
}

merge_branch_into() {
  local src="$1"
  local dst="$2"
  local msg="$3"

  if ! branch_exists "${src}"; then
    log "SKIP ${src} → ${dst} (source branch missing on origin)"
    return 0
  fi

  local ahead
  ahead="$(commits_ahead "${dst}" "${src}")"
  if [[ "${ahead}" -eq 0 ]]; then
    log "SKIP ${src} → ${dst} (already merged / 0 commits ahead)"
    return 0
  fi

  log "PLAN: merge origin/${src} (${ahead} commits) into ${dst}"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi

  if [[ "${dst}" == "main" ]]; then
    git checkout main
    git pull origin main
  else
    if git show-ref --verify --quiet "refs/heads/${dst}"; then
      git checkout "${dst}"
    else
      git checkout -b "${dst}" "origin/${dst}"
    fi
    git pull origin "${dst}" 2>/dev/null || true
  fi

  if ! git merge --no-ff "origin/${src}" -m "${msg}"; then
    die "merge conflict: ${src} → ${dst}. Resolve manually, then re-run."
  fi

  if [[ "${dst}" != "main" ]]; then
    log "pushing ${dst}..."
    git push origin "${dst}"
  fi

  log "OK ${src} → ${dst}"
}

run_merges() {
  fetch_all

  log "=== Core merge sequence ==="
  merge_branch_into "${VAULT_BRANCH}" "${PROD_BRANCH}" \
    "Merge ${VAULT_BRANCH} into ${PROD_BRANCH} (Vault Akash runtime injection)"
  merge_branch_into "${PROD_BRANCH}" "main" \
    "Merge ${PROD_BRANCH} into main (production prep)"
  merge_branch_into "${GOD_BRANCH}" "main" \
    "Merge ${GOD_BRANCH} into main (God Prompt swarm)"
  merge_branch_into "${SOV_BRANCH}" "main" \
    "Merge ${SOV_BRANCH} into main (sovereign loops live)"
  merge_branch_into "${AKASH_BRANCH}" "main" \
    "Merge ${AKASH_BRANCH} into main (Akash real deploy)"

  if [[ "${INCLUDE_OPTIONAL}" -eq 1 ]]; then
    log "=== Optional merge sequence ==="
    merge_branch_into "${KAIRO_BRANCH}" "main" \
      "Merge ${KAIRO_BRANCH} into main (Kairo integration)"
    merge_branch_into "${TESLA_BRANCH}" "main" \
      "Merge ${TESLA_BRANCH} into main (Tesla Fleet API)"
    merge_branch_into "${MULTI_BRANCH}" "main" \
      "Merge ${MULTI_BRANCH} into main (multi-cloud 30-day plan)"
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    log "DRY RUN complete — no merges performed"
    return 0
  fi

  if [[ "${PUSH}" -eq 1 ]]; then
    log "pushing main to origin..."
    git checkout main
    git push origin main
    log "main pushed"
  else
    log "local merges complete — run with --push to publish main"
  fi
}

preflight_checks() {
  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree dirty — commit or stash before merging"
  fi
}

main() {
  log "YieldSwarm safe stacked PR merge"
  [[ "${DRY_RUN}" -eq 1 ]] || preflight_checks

  log "Core order:"
  for m in "${CORE_MERGES[@]}"; do log "  ${m}"; done
  if [[ "${INCLUDE_OPTIONAL}" -eq 1 ]]; then
    log "Optional:"
    for m in "${OPTIONAL_MERGES[@]}"; do log "  ${m}"; done
  fi

  run_merges

  log ""
  log "Next steps:"
  log "  make smoke"
  log "  make start-sovereign-consensus"
  log "  make akash-preflight    # human: VAULT_TOKEN + wallet funded"
  log "  make deploy-akash-europlots"
}

main "$@"
