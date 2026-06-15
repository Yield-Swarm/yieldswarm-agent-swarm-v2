#!/usr/bin/env bash
#
# seed-secrets.sh — Write the YieldSwarm secret tree into Vault KV v2.
#
# Values are read from the current ENVIRONMENT (never hardcoded here). Populate
# them however you like before running, for example:
#
#   set -a; source ./secrets.env; set +a   # secrets.env is .gitignored
#   ./seed-secrets.sh
#
# Only variables that are actually set and non-empty are written; missing ones
# are skipped (with a warning) so you can seed incrementally.
#
# Secret values are passed to Vault as a JSON document on STDIN, so they never
# appear in the process argument list, shell history, or `ps` output.
#
# Required environment:
#   VAULT_ADDR   e.g. https://vault.example.com:8200
#   VAULT_TOKEN  a token with the 'secrets-admin' policy
#
# Optional environment:
#   KV_MOUNT     KV v2 mount path (default: secret)
#
set -euo pipefail

KV_MOUNT="${KV_MOUNT:-secret}"

log()  { printf '\033[1;34m[seed]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[seed]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[seed]\033[0m %s\n' "$*" >&2; exit 1; }

command -v vault >/dev/null 2>&1 || die "vault CLI not found on PATH."
command -v jq    >/dev/null 2>&1 || die "jq not found on PATH."
: "${VAULT_ADDR:?VAULT_ADDR must be set}"
: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

# put_secret <vault-path> <KEY_MAPPING...>
# Each KEY_MAPPING is "VAULT_KEY=ENV_VAR_NAME". The function collects the
# values of the named environment variables (skipping unset/empty ones),
# builds a JSON object keyed by VAULT_KEY, and pipes it to `vault kv put`.
put_secret() {
  path="$1"; shift
  json='{}'
  written=0
  skipped=""
  for mapping in "$@"; do
    vkey="${mapping%%=*}"
    evar="${mapping#*=}"
    # Indirect expansion of the env var named by $evar.
    val="${!evar-}"
    if [ -z "${val}" ]; then
      skipped="${skipped} ${evar}"
      continue
    fi
    json="$(printf '%s' "$json" | jq --arg k "$vkey" --arg v "$val" '. + {($k): $v}')"
    written=$((written + 1))
  done

  if [ "$written" -eq 0 ]; then
    warn "Skipping ${KV_MOUNT}/${path}: no source env vars were set."
    return 0
  fi

  printf '%s' "$json" | vault kv put -mount="${KV_MOUNT}" "${path}" - >/dev/null
  log "Wrote ${written} key(s) to ${KV_MOUNT}/${path}.${skipped:+ (skipped:${skipped})}"
}

log "Seeding secrets into Vault KV mount '${KV_MOUNT}/' at ${VAULT_ADDR}"

# --- Cloud provider credentials (consumed by Terraform) ---------------------
put_secret "yieldswarm/cloud/azure" \
  "arm_client_id=ARM_CLIENT_ID" \
  "arm_client_secret=ARM_CLIENT_SECRET" \
  "arm_tenant_id=ARM_TENANT_ID" \
  "arm_subscription_id=ARM_SUBSCRIPTION_ID"

put_secret "yieldswarm/cloud/runpod" \
  "api_key=RUNPOD_API_KEY"

put_secret "yieldswarm/cloud/vultr" \
  "api_key=VULTR_API_KEY"

put_secret "yieldswarm/cloud/digitalocean" \
  "token=DIGITALOCEAN_TOKEN"

# --- Blockchain / RPC (consumed by Terraform AND the Akash runtime) ---------
put_secret "yieldswarm/rpc" \
  "SOLANA_RPC_URL=SOLANA_RPC_URL" \
  "HELIUS_API_KEY=HELIUS_API_KEY" \
  "BIRDEYE_API_KEY=BIRDEYE_API_KEY" \
  "JUPITER_API_KEY=JUPITER_API_KEY" \
  "RAYDIUM_API_KEY=RAYDIUM_API_KEY" \
  "TON_API_KEY=TON_API_KEY" \
  "TAO_SUBNET_KEY=TAO_SUBNET_KEY" \
  "FAILOVER_RPC_LIST=FAILOVER_RPC_LIST"

# --- Application runtime bundle (consumed by the Akash runtime) -------------
put_secret "yieldswarm/app" \
  "AGENTSWARM_MASTER_KEY=AGENTSWARM_MASTER_KEY" \
  "KIMICLAW_CONSENSUS_KEY=KIMICLAW_CONSENSUS_KEY" \
  "GROK_API_KEY=GROK_API_KEY" \
  "OPENAI_API_KEY=OPENAI_API_KEY" \
  "GEMINI_API_KEY=GEMINI_API_KEY" \
  "ANTHROPIC_API_KEY=ANTHROPIC_API_KEY" \
  "WALLET_ENCRYPTION_KEY=WALLET_ENCRYPTION_KEY" \
  "TEE_SIGNING_KEY=TEE_SIGNING_KEY" \
  "DATABASE_ENCRYPTION_KEY=DATABASE_ENCRYPTION_KEY" \
  "TELEGRAM_BOT_TOKEN=TELEGRAM_BOT_TOKEN" \
  "GITHUB_TOKEN=GITHUB_TOKEN" \
  "NOTION_API_KEY=NOTION_API_KEY" \
  "LINEAR_API_KEY=LINEAR_API_KEY" \
  "VERCEL_API_TOKEN=VERCEL_API_TOKEN" \
  "PUMP_FUN_DEPLOY_KEY=PUMP_FUN_DEPLOY_KEY"

log "Done. Verify with: vault kv list -mount=${KV_MOUNT} yieldswarm"
