#!/usr/bin/env bash
# sync-fork-repos.sh — Multi-chain SDK synchronizer & patcher (God Prompt 1)
#
# Clones 22 upstream SDK repos, creates yieldswarm-migration-v2 branches,
# patches package identifiers, and injects YIELDSWARM_ROUTING.json.
#
# Usage:
#   ./scripts/sdk/sync-fork-repos.sh [--dry-run] [--workspace PATH]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MANIFEST="${REPO_ROOT}/config/sdk-fork/manifest.json"
ROUTING_TEMPLATE="${REPO_ROOT}/config/sdk-fork/YIELDSWARM_ROUTING.json"
LOG_DIR="${REPO_ROOT}/logs/sdk-sync"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="${LOG_DIR}/sync-${TIMESTAMP}.log"

DRY_RUN=0
WORKSPACE_OVERRIDE=""

# ── Colors ──────────────────────────────────────────────────────────────────
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  C_RESET="$(tput sgr0)" C_RED="$(tput setaf 1)" C_GRN="$(tput setaf 2)"
  C_YLW="$(tput setaf 3)" C_BLU="$(tput setaf 4)" C_CYN="$(tput setaf 6)"
else
  C_RESET= C_RED= C_GRN= C_YLW= C_BLU= C_CYN=
fi

log()  { local lvl="$1"; shift; local msg="$*"; echo -e "${C_CYN}[$(date -u +%H:%M:%S)]${C_RESET} [$lvl] $msg" | tee -a "$LOG_FILE"; }
info() { log "INFO" "$@"; }
ok()   { log "${C_GRN}OK${C_RESET}" "$@"; }
warn() { log "${C_YLW}WARN${C_RESET}" "$@"; }
err()  { log "${C_RED}ERR${C_RESET}" "$@" >&2; }
die()  { err "$@"; exit 1; }

usage() {
  sed -n '3,8p' "$0"
  echo "  --dry-run           Preview mutations without writing files"
  echo "  --workspace PATH    Override workspace directory from manifest"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --workspace) WORKSPACE_OVERRIDE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) die "Unknown arg: $1" ;;
  esac
done

mkdir -p "$LOG_DIR"
info "YieldSwarm SDK fork synchronizer — dry_run=$DRY_RUN"
info "Log: $LOG_FILE"

command -v jq >/dev/null 2>&1 || die "jq is required"
command -v git >/dev/null 2>&1 || die "git is required"

BRANCH="$(jq -r '.branch' "$MANIFEST")"
WORKSPACE_REL="$(jq -r '.workspace' "$MANIFEST")"
DEPTH="$(jq -r '.clone_depth' "$MANIFEST")"
ROUTING_NAME="$(jq -r '.routing_file' "$MANIFEST")"
WORKSPACE="${WORKSPACE_OVERRIDE:-${REPO_ROOT}/${WORKSPACE_REL}}"

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "[dry-run] $*"
  else
    "$@"
  fi
}

detect_stack() {
  local dir="$1"
  if [[ -f "${dir}/package.json" ]]; then echo "node"
  elif [[ -f "${dir}/Cargo.toml" ]]; then echo "rust"
  elif [[ -f "${dir}/go.mod" ]]; then echo "go"
  else echo "unknown"
  fi
}

patch_node() {
  local dir="$1" id="$2"
  local pkg="${dir}/package.json"
  [[ -f "$pkg" ]] || return 0
  local name
  name="$(jq -r '.name // empty' "$pkg")"
  [[ -n "$name" && "$name" != null ]] || return 0
  if [[ "$name" == yieldswarm-fork-* ]]; then
    warn "  package.json already prefixed: $name"
    return 0
  fi
  info "  patch package.json name → yieldswarm-fork-${id}"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    local tmp
    tmp="$(mktemp)"
    jq --arg n "yieldswarm-fork-${id}" '.name = $n' "$pkg" > "$tmp" && mv "$tmp" "$pkg"
  fi
}

patch_rust() {
  local dir="$1" id="$2"
  local cargo="${dir}/Cargo.toml"
  [[ -f "$cargo" ]] || return 0
  if grep -q 'yieldswarm-fork-' "$cargo" 2>/dev/null; then
    warn "  Cargo.toml already patched"
    return 0
  fi
  info "  patch Cargo.toml package name → yieldswarm-fork-${id}"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    sed -i.bak -E "s/^name = \"([^\"]+)\"/name = \"yieldswarm-fork-${id}\"/" "$cargo" 2>/dev/null || true
    rm -f "${cargo}.bak"
  fi
}

patch_go() {
  local dir="$1" id="$2"
  local gomod="${dir}/go.mod"
  [[ -f "$gomod" ]] || return 0
  local module
  module="$(head -1 "$gomod" | awk '{print $2}')"
  [[ -n "$module" ]] || return 0
  if [[ "$module" == *yieldswarm-fork-* ]]; then
    warn "  go.mod already prefixed"
    return 0
  fi
  info "  patch go.mod module → yieldswarm-fork/${id}"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    sed -i.bak "1s|${module}|yieldswarm-fork/${id}|" "$gomod"
    rm -f "${gomod}.bak"
  fi
}

inject_routing() {
  local dir="$1"
  local dest="${dir}/${ROUTING_NAME}"
  if [[ -f "$dest" ]]; then
    warn "  ${ROUTING_NAME} exists — skip inject"
    return 0
  fi
  info "  inject ${ROUTING_NAME}"
  if [[ "$DRY_RUN" -eq 0 ]]; then
    cp "$ROUTING_TEMPLATE" "$dest"
  fi
}

git_commit_all() {
  local dir="$1" id="$2"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    info "[dry-run] would commit in $id"
    return 0
  fi
  (
    cd "$dir"
    git add -A
    if git diff --cached --quiet; then
      warn "  no changes to commit for $id"
      git commit --allow-empty -m "chore(yieldswarm): sync fork baseline [${TIMESTAMP}]" >/dev/null 2>&1 || true
    else
      git commit -m "chore(yieldswarm): fork patch + routing inject [${TIMESTAMP}]" >/dev/null
      ok "  committed $id"
    fi
  )
}

process_repo() {
  local id="$1" url="$2" expected_stack="$3"
  local dest="${WORKSPACE}/${id}"
  info "── ${id} (${url})"

  if [[ ! -d "${dest}/.git" ]]; then
    info "  clone → ${dest}"
    run mkdir -p "$(dirname "$dest")"
    run git clone --depth "$DEPTH" --branch "$(git ls-remote --symref "$url" HEAD 2>/dev/null | awk '/ref:/ {print $2; exit}' | sed 's|refs/heads/||')" "$url" "$dest" 2>/dev/null \
      || run git clone --depth "$DEPTH" "$url" "$dest"
  else
    info "  fetch upstream"
    if [[ "$DRY_RUN" -eq 0 ]]; then
      (cd "$dest" && git fetch --depth "$DEPTH" origin 2>/dev/null || true)
    fi
  fi

  if [[ "$DRY_RUN" -eq 0 ]]; then
    (
      cd "$dest"
      git checkout -B "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"
    )
  else
    info "[dry-run] checkout -B $BRANCH"
  fi

  local stack
  stack="$(detect_stack "$dest")"
  if [[ "$expected_stack" != "$stack" && "$stack" != unknown ]]; then
    warn "  stack mismatch manifest=$expected_stack detected=$stack"
  fi

  case "$stack" in
    node) patch_node "$dest" "$id" ;;
    rust) patch_rust "$dest" "$id" ;;
    go)   patch_go "$dest" "$id" ;;
    *)    warn "  unknown stack — routing inject only" ;;
  esac

  inject_routing "$dest"
  git_commit_all "$dest" "$id"
}

main() {
  local count
  count="$(jq '.repositories | length' "$MANIFEST")"
  info "Workspace: $WORKSPACE | branch: $BRANCH | repos: $count"
  run mkdir -p "$WORKSPACE"

  local i id url stack
  for i in $(seq 0 $((count - 1))); do
    id="$(jq -r ".repositories[$i].id" "$MANIFEST")"
    url="$(jq -r ".repositories[$i].url" "$MANIFEST")"
    stack="$(jq -r ".repositories[$i].stack" "$MANIFEST")"
    process_repo "$id" "$url" "$stack" || err "failed: $id"
  done

  ok "SDK sync complete — $count repositories processed"
  [[ "$DRY_RUN" -eq 1 ]] && warn "Dry-run mode: no files were modified"
}

trap 'err "Aborted at line $LINENO"; exit 1' ERR
main "$@"
