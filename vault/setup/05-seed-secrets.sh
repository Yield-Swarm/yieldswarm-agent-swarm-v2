#!/usr/bin/env bash
# vault/setup/05-seed-secrets.sh
#
# Optional convenience: import an operator's local .env into KVv2 under
# the YieldSwarm path conventions. Should be run only on a trusted
# (air-gapped / TEE) workstation. Never run inside CI.
#
# Path layout (KVv2 mount `yieldswarm/`):
#   yieldswarm/cloud/azure          # azure SP creds
#   yieldswarm/cloud/runpod         # runpod api key
#   yieldswarm/cloud/vultr          # vultr api key
#   yieldswarm/cloud/digitalocean   # do token
#   yieldswarm/rpc/helius           # helius
#   yieldswarm/rpc/birdeye          # birdeye
#   yieldswarm/rpc/jupiter          # jupiter
#   yieldswarm/rpc/solana           # solana http+ws urls
#   yieldswarm/llm/openai
#   yieldswarm/llm/anthropic
#   yieldswarm/llm/grok
#   yieldswarm/llm/gemini
#   yieldswarm/akash/runtime        # AKASH_KEYRING, wallet, lease meta
#   yieldswarm/agents/shards/<id>   # per-shard fanout
#
# Required env: VAULT_ADDR, VAULT_TOKEN, SOURCE_ENV (path to .env file)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib.sh"
require_token

SOURCE_ENV="${SOURCE_ENV:-./.env}"
[ -r "${SOURCE_ENV}" ] || die "SOURCE_ENV not readable: ${SOURCE_ENV}"

# Helper: pull a value out of the .env file safely (no shell eval).
val() {
  local k="$1"
  awk -F= -v k="${k}" 'BEGIN{f=0} $0 !~ /^#/ && $1==k { f=1; sub(/^[^=]*=/,""); print; exit } END{ if(!f) exit 1 }' "${SOURCE_ENV}" || true
}

put() {
  local path="$1"; shift
  log "vault kv put yieldswarm/${path}"
  vault kv put "yieldswarm/${path}" "$@" >/dev/null
}

# ---- Cloud providers ---------------------------------------------------
put cloud/azure \
  client_id="$(val AZURE_CLIENT_ID)" \
  client_secret="$(val AZURE_CLIENT_SECRET)" \
  tenant_id="$(val AZURE_TENANT_ID)" \
  subscription_id="$(val AZURE_SUBSCRIPTION_ID)"

put cloud/runpod \
  api_key="$(val RUNPOD_API_KEY)"

put cloud/vultr \
  api_key="$(val VULTR_API_KEY)" \
  ssh_public_key="$(val DEPLOY_SSH_PUBLIC_KEY)"

put cloud/digitalocean \
  token="$(val DIGITALOCEAN_TOKEN)" \
  ssh_public_key="$(val DEPLOY_SSH_PUBLIC_KEY)"

# ---- RPC / chain providers --------------------------------------------
put rpc/helius   api_key="$(val HELIUS_API_KEY)"
put rpc/birdeye  api_key="$(val BIRDEYE_API_KEY)"
put rpc/jupiter  api_key="$(val JUPITER_API_KEY)"
put rpc/solana   http_url="$(val SOLANA_RPC_URL)" ws_url="$(val SOLANA_WS_URL)"
put rpc/raydium  api_key="$(val RAYDIUM_API_KEY)"
put rpc/ton      api_key="$(val TON_API_KEY)"

# ---- LLM providers -----------------------------------------------------
put llm/openai    api_key="$(val OPENAI_API_KEY)"
put llm/anthropic api_key="$(val ANTHROPIC_API_KEY)"
put llm/grok      api_key="$(val GROK_API_KEY)"
put llm/gemini    api_key="$(val GEMINI_API_KEY)"

# ---- Akash runtime bundle ---------------------------------------------
put akash/runtime \
  master_key="$(val AGENTSWARM_MASTER_KEY)" \
  kimiclaw_key="$(val KIMICLAW_CONSENSUS_KEY)" \
  wallet_encryption_key="$(val WALLET_ENCRYPTION_KEY)" \
  tee_signing_key="$(val TEE_SIGNING_KEY)" \
  database_encryption_key="$(val DATABASE_ENCRYPTION_KEY)"

# ---- Integrations -----------------------------------------------------
put integrations/notion   api_key="$(val NOTION_API_KEY)"
put integrations/linear   api_key="$(val LINEAR_API_KEY)"
put integrations/github   token="$(val GITHUB_TOKEN)"
put integrations/vercel   token="$(val VERCEL_API_TOKEN)"
put integrations/telegram bot_token="$(val TELEGRAM_BOT_TOKEN)"

log "Seed complete. Verify with: vault kv list yieldswarm/"
