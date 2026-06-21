#!/usr/bin/env bash
# =============================================================================
# scripts/deploy-production.sh — Unified multi-platform production deploy
#
# Usage:
#   ./scripts/deploy-production.sh <target> [options]
#
# Targets:
#   all              Full pipeline (vault → images → akash → terraform → frontend)
#   vault            Bootstrap + seed HashiCorp Vault (operator)
#   akash            Default agent shard (Vault-injected monolith SDL)
#   akash-bittensor  Bittensor miner (RTX 3090)
#   akash-odysseus   Odysseus GPU worker (Vault SDL)
#   akash-backend    Light integration API on Akash
#   terraform        Multi-cloud fallback (deploy/terraform)
#   azure            Root terraform/ apply (Container Apps + Vault-fed creds)
#   azure-aci          Azure Container Instances (deploy/azure-deploy.yml)
#   vercel           Print Vercel deploy command (or trigger hook)
#   render           Render blueprint / API redeploy hint
#   frontend         Wire worker URLs into dashboard config
#   status           Show Akash lease + loop status
#
# Environment:
#   Copy deploy/config.env.example → deploy/config.env
#   export VAULT_ADDR VAULT_TOKEN for Vault minting
# =============================================================================
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/deploy/scripts/lib.sh" 2>/dev/null || true

TARGET="${1:-all}"
shift || true

load_config 2>/dev/null || true

export REPO_ROOT="${REPO_ROOT:-$ROOT}"
export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"
export VAULT_INJECT_RUNTIME_SECRETS="${VAULT_INJECT_RUNTIME_SECRETS:-auto}"

log() { echo "[$(date -u +%FT%TZ)] [deploy-production] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

cmd_vault() {
  log "Vault bootstrap (policies + AppRoles + seed)"
  [[ -n "${VAULT_TOKEN:-}" ]] || die "Set VAULT_TOKEN for vault bootstrap"
  if [[ -x "${ROOT}/vault/setup/bootstrap.sh" ]]; then
    bash "${ROOT}/vault/setup/bootstrap.sh"
  fi
  if [[ -x "${ROOT}/vault/scripts/seed-secrets.sh" ]]; then
    bash "${ROOT}/vault/scripts/seed-secrets.sh"
  fi
  log "Vault bootstrap complete — see docs/VAULT_AKASH_RUNTIME.md"
}

cmd_akash() {
  export USE_VAULT_AKASH=1
  export SDL_FILE="${SDL_FILE:-deploy/deploy-swarm-monolith.yaml}"
  export VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
  bash "${ROOT}/deploy/scripts/akash-production-deploy.sh" "${SDL_FILE}"
}

cmd_akash_bittensor() {
  : "${BT_NETUID:?Set BT_NETUID for Bittensor deploy}"
  export VAULT_AKASH_ROLE=bittensor-runtime
  bash "${ROOT}/scripts/deploy-bittensor.sh"
}

cmd_akash_odysseus() {
  export VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
  export ODYSSEUS_IMAGE="${ODYSSEUS_IMAGE:-ghcr.io/${GHCR_OWNER:-yield-swarm}/odysseus:${IMAGE_TAG:-latest}}"
  export ODYSSEUS_AGENT_COUNT="${ODYSSEUS_AGENT_COUNT:-84}"
  export AKASH_SDL="${AKASH_SDL:-deploy/akash/odysseus-vault.sdl.yml}"
  local rendered="${ROOT}/.run/odysseus-vault.rendered.yml"
  mkdir -p "${ROOT}/.run"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst '${ODYSSEUS_IMAGE} ${ODYSSEUS_AGENT_COUNT}' \
      < "${ROOT}/deploy/akash/odysseus-vault.sdl.yml" > "${rendered}"
  else
    cp "${ROOT}/deploy/akash/odysseus-vault.sdl.yml" "${rendered}"
  fi
  bash "${ROOT}/scripts/deploy-to-akash.sh" deploy "${rendered}"
}

cmd_akash_backend() {
  export VAULT_AKASH_ROLE="${VAULT_AKASH_ROLE:-akash-runtime}"
  export BACKEND_IMAGE="${BACKEND_IMAGE:-ghcr.io/${GHCR_OWNER:-yield-swarm}/yieldswarm-backend:${IMAGE_TAG:-latest}}"
  export AKASH_SDL="${AKASH_SDL:-deploy/akash-backend.sdl.yml}"
  local rendered="${ROOT}/.run/akash-backend.rendered.yml"
  mkdir -p "${ROOT}/.run"
  if command -v envsubst >/dev/null 2>&1; then
    envsubst '${BACKEND_IMAGE}' < "${ROOT}/deploy/akash-backend.sdl.yml" > "${rendered}"
  else
    cp "${ROOT}/deploy/akash-backend.sdl.yml" "${rendered}"
  fi
  bash "${ROOT}/scripts/deploy-to-akash.sh" deploy "${rendered}"
}

cmd_terraform() {
  bash "${ROOT}/deploy/scripts/apply-terraform.sh" apply
}

cmd_azure() {
  log "Applying root terraform/ (Azure Container Apps + Vault-fed providers)"
  (cd "${ROOT}/terraform" && terraform init -backend-config=envs/prod/backend.hcl && terraform apply)
}

cmd_azure_aci() {
  log "Deploying YieldSwarm core to Azure Container Instances"
  bash "${ROOT}/scripts/deploy-azure-core.sh" "$@"
}

cmd_vercel() {
  if [[ -n "${VERCEL_DEPLOY_HOOK:-}" ]]; then
    log "Triggering Vercel deploy hook"
    curl -fsS -X POST "${VERCEL_DEPLOY_HOOK}"
    log "Vercel hook triggered"
  else
    cat <<EOF
Vercel deploy (run from repo root):

  vercel deploy --prod

Or set VERCEL_DEPLOY_HOOK in deploy/config.env for CI triggers.
Config: vercel.json (kairo, dashboard, council, Next.js app)
EOF
  fi
}

cmd_render() {
  if [[ -f "${ROOT}/render.yaml" ]]; then
    cat <<EOF
Render blueprint: render.yaml

  1. Connect repo at https://dashboard.render.com
  2. New > Blueprint > select render.yaml
  3. Set secrets: SOLANA_RPC_URL, TREASURY_ADDRESS, VAULT_TOKEN, ...

Or enable fallback redeploy:
  TF_ENABLE_RENDER=true RENDER_API_KEY=... bash deploy/terraform/scripts/deploy-render.sh
EOF
  else
    die "render.yaml not found"
  fi
}

cmd_frontend() {
  bash "${ROOT}/deploy/scripts/update-frontend-urls.sh"
}

cmd_status() {
  bash "${ROOT}/deploy/scripts/start-sovereign-loops.sh" status 2>/dev/null || true
  [[ -f "${ROOT}/.run/akash-deploy.json" ]] && jq . "${ROOT}/.run/akash-deploy.json" 2>/dev/null || true
}

cmd_all() {
  cmd_vault 2>/dev/null || log "vault bootstrap skipped (no VAULT_TOKEN)"
  bash "${ROOT}/deploy.sh" "$@"
}

case "${TARGET}" in
  all)              cmd_all "$@" ;;
  vault)            cmd_vault ;;
  akash)            cmd_akash ;;
  akash-bittensor)  cmd_akash_bittensor ;;
  akash-odysseus)   cmd_akash_odysseus ;;
  akash-backend)    cmd_akash_backend ;;
  terraform)        cmd_terraform ;;
  azure)            cmd_azure ;;
  azure-aci)        cmd_azure_aci "$@" ;;
  vercel)           cmd_vercel ;;
  render)           cmd_render ;;
  frontend)         cmd_frontend ;;
  status)           cmd_status ;;
  -h|--help)
    sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *) die "unknown target: ${TARGET} (try --help)" ;;
esac
