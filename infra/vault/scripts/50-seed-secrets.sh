#!/usr/bin/env bash
# 50-seed-secrets.sh
# Seeds the KV v2 store with cloud-provider creds + RPC URLs + app secrets.
#
# Reads from a single JSON bundle pointed to by $SECRETS_BUNDLE.  The bundle
# must be produced in an air-gapped environment (TEE recommended) and shredded
# immediately after this script completes.
#
# Bundle schema (top-level keys mirror the on-disk Vault layout):
# {
#   "azure":        { "client_id": "...", "client_secret": "...", "tenant_id": "...", "subscription_id": "...", "location": "westus2", "resource_group": "yieldswarm-prod" },
#   "runpod":       { "api_key": "...", "pod_template_id": "..." },
#   "vultr":        { "api_key": "...", "region": "ewr", "plan": "vc2-2c-4gb" },
#   "digitalocean": { "token": "...", "spaces_access_key": "...", "spaces_secret_key": "...", "region": "nyc3", "droplet_size": "s-2vcpu-4gb" },
#   "rpc": {
#     "solana": { "url": "...", "helius_api_key": "...", "jupiter_api_key": "...", "birdeye_api_key": "...", "raydium_api_key": "..." },
#     "eth":    { "mainnet_url": "...", "sepolia_url": "...", "bundler_url": "..." },
#     "ton":    { "url": "...", "api_key": "..." },
#     "tao":    { "url": "...", "subnet_key": "..." }
#   },
#   "akash":        { "wallet_mnemonic": "...", "keyring_passphrase": "...", "provider_uri": "https://provider.akash.network:8443", "chain_id": "akashnet-2" },
#   "app":          { "agentswarm": { "master_key": "...", "kimiclaw_key": "...", "grok_api_key": "...", ... } }
# }

set -Eeuo pipefail
# shellcheck source=lib/common.sh
. "$(dirname "$0")/lib/common.sh"
vault_check
require_env VAULT_TOKEN SECRETS_BUNDLE
[[ -r "$SECRETS_BUNDLE" ]] || die "SECRETS_BUNDLE not readable: $SECRETS_BUNDLE"

write_kv() {
  local subpath="$1" json="$2"
  local full="${KV_MOUNT}/data/yieldswarm/${YS_ENV}/${subpath}"
  log "writing $full"
  printf '%s' "$json" \
    | jq '{data: .}' \
    | vault write "$full" - >/dev/null
}

bundle="$(cat "$SECRETS_BUNDLE")"

for k in azure runpod vultr digitalocean akash; do
  v="$(jq -c --arg k "$k" '.[$k] // empty' <<<"$bundle")"
  [[ -n "$v" ]] || { log "skip $k (not in bundle)"; continue; }
  write_kv "$k" "$v"
done

for k in solana eth ton tao; do
  v="$(jq -c --arg k "$k" '.rpc[$k] // empty' <<<"$bundle")"
  [[ -n "$v" ]] || { log "skip rpc/$k (not in bundle)"; continue; }
  write_kv "rpc/$k" "$v"
done

for k in $(jq -r '.app // {} | keys[]' <<<"$bundle"); do
  v="$(jq -c --arg k "$k" '.app[$k]' <<<"$bundle")"
  write_kv "app/$k" "$v"
done

log "seed complete -- shred ${SECRETS_BUNDLE} now"
