#!/usr/bin/env bash
# Analyze all origin/cursor/* branches against main.
# Usage: ./scripts/analyze-cursor-branches.sh [--json]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

echo "==> Fetching origin..."
git fetch origin --prune

MAIN="$(git rev-parse main)"
MAIN_SHORT="$(git rev-parse --short "$MAIN")"

declare -a MERGE_NEXT=()
declare -a REVIEW=()
declare -a ABSORBED=()
declare -a CLOSE=()
declare -a STALE=()

is_vault_dup() {
  [[ "$1" =~ vault-integration|hashicorp-vault-integration|vault-secrets-integration|complete-vault-integration ]]
}

is_stale_mega() {
  [[ "$1" =~ (stripe-payment-flow|domains-wiring|akash-deploy-jwt|god-prompt-full-system)-597f ]]
}

while IFS= read -r branch; do
  [[ -z "$branch" ]] && continue
  ahead="$(git rev-list --count "$MAIN..origin/$branch" 2>/dev/null || echo 0)"
  behind="$(git rev-list --count "origin/$branch..$MAIN" 2>/dev/null || echo 0)"
  files="$(git diff --name-only "$MAIN...origin/$branch" 2>/dev/null | wc -l | tr -d ' ')"

  if [[ "$ahead" -eq 0 ]]; then
    ABSORBED+=("$branch|0|$behind|0")
  elif is_stale_mega "$branch" || { is_vault_dup "$branch" && [[ "$behind" -ge 70 ]]; }; then
    CLOSE+=("$branch|$ahead|$behind|$files")
  elif [[ "$branch" == "cursor/helix-chain-activation-597f" ]]; then
    REVIEW+=("$branch|$ahead|$behind|$files")
  elif [[ "$branch" == "cursor/odysseus-brain-e512" ]] || [[ "$branch" == "cursor/mega-round-integration-e512" ]]; then
    MERGE_NEXT+=("$branch|$ahead|$behind|$files")
  elif [[ "$behind" -ge 70 && "$files" -ge 20 ]]; then
    STALE+=("$branch|$ahead|$behind|$files")
  elif [[ "$files" -le 3 && "$behind" -ge 70 ]]; then
    CLOSE+=("$branch|$ahead|$behind|$files")
  else
    REVIEW+=("$branch|$ahead|$behind|$files")
  fi
done < <(git branch -r | sed -n 's|^[[:space:]]*origin/||p' | grep '^cursor/' | sort)

print_section() {
  local title="$1"
  shift
  local -a rows=("$@")
  echo ""
  echo "=== $title (${#rows[@]}) ==="
  if [[ ${#rows[@]} -eq 0 ]]; then
    echo "  (none)"
    return
  fi
  printf "  %-50s %6s %7s %6s\n" "BRANCH" "AHEAD" "BEHIND" "FILES"
  printf "  %-50s %6s %7s %6s\n" "------" "-----" "------" "-----"
  for row in "${rows[@]}"; do
    IFS='|' read -r b a be f <<< "$row"
    printf "  %-50s %6s %7s %6s\n" "$b" "$a" "$be" "$f"
  done
}

if $JSON; then
  echo "{\"main\":\"$MAIN_SHORT\",\"merge_next\":[$(printf '"%s",' "${MERGE_NEXT[@]%%|*}" | sed 's/,$//')],\"absorbed_count\":${#ABSORBED[@]},\"close_count\":${#CLOSE[@]}}"
  exit 0
fi

echo "YieldSwarm cursor/* branch analysis"
echo "main tip: $MAIN_SHORT ($(git log -1 --format='%s' "$MAIN"))"
echo "cursor branches: $((${#MERGE_NEXT[@]} + ${#REVIEW[@]} + ${#ABSORBED[@]} + ${#CLOSE[@]} + ${#STALE[@]}))"

print_section "MERGE NEXT → development" "${MERGE_NEXT[@]}"
print_section "REVIEW on development only" "${REVIEW[@]}"
print_section "ALREADY ON main (0 commits ahead)" "${ABSORBED[@]}"
print_section "CLOSE without merge (duplicates / superseded)" "${CLOSE[@]}"
print_section "STALE (large diff, diverged history)" "${STALE[@]}"

echo ""
echo "Environment branches vs main:"
for env in development testnet devnets production MAINNET; do
  if git show-ref --verify --quiet "refs/remotes/origin/$env"; then
    tip="$(git rev-parse --short "origin/$env")"
    behind="$(git rev-list --count "origin/$env..$MAIN")"
    ahead="$(git rev-list --count "$MAIN..origin/$env")"
    status="ok"
    [[ "$behind" -gt 0 ]] && status="behind main by $behind"
    [[ "$ahead" -gt 0 ]] && status="ahead of main by $ahead"
    echo "  $env @ $tip — $status"
  else
    echo "  $env — MISSING (run ./scripts/sync-environment-branches.sh --init)"
  fi
done

echo ""
echo "Recommended actions:"
echo "  1. Merge cursor/odysseus-brain-e512 → development → main"
echo "  2. Merge cursor/mega-round-integration-e512 → development → main"
echo "  3. ./scripts/sync-environment-branches.sh"
echo "  4. Close ${#CLOSE[@]} duplicate/stale PRs"
echo "See MERGE_STRATEGY.md and BRANCHES.md for full workflow."
