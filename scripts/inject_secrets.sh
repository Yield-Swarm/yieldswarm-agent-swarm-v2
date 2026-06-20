#!/usr/bin/env bash
# inject_secrets.sh — Securely provisions secrets to Azure Key Vault.
#
# Secrets are read with read -sp (no echo). Values are never printed, logged,
# or passed on the command line (which would leak into process listings).
#
# Prerequisites:
#   az login
#   az account set --subscription "$AZURE_SUBSCRIPTION_ID"   # optional
#
# Usage:
#   export AZURE_KEYVAULT_NAME=your-unique-keyvault
#   ./scripts/inject_secrets.sh
#   ./scripts/inject_secrets.sh --dry-run          # list secret names only
#   ./scripts/inject_secrets.sh --only grok-api-key,pinata-jwt
#
# See docs/PHASE1_SECURE_ENV.md for KV name ↔ env var mapping.

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DRY_RUN=0
ONLY_FILTER=""

usage() {
  cat <<'EOF'
Usage: inject_secrets.sh [options]

Options:
  --dry-run           Print secret names that would be injected; do not write.
  --only a,b,c        Inject only the listed Key Vault secret names.
  -h, --help          Show this help.

Environment:
  AZURE_KEYVAULT_NAME   Target vault (prompted if unset).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --only) ONLY_FILTER="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# Key Vault secret name → human prompt label (values never stored in script)
declare -A SECRET_LABELS=(
  [agentswarm-master-key]="AGENTSWARM_MASTER_KEY"
  [kimiclaw-consensus-key]="KIMICLAW_CONSENSUS_KEY"
  [grok-api-key]="GROK_API_KEY"
  [openai-api-key]="OPENAI_API_KEY"
  [gemini-api-key]="GEMINI_API_KEY"
  [openrouter-api-key]="OPENROUTER_API_KEY"
  [tee-signing-key]="TEE_SIGNING_KEY"
  [database-encryption-key]="DATABASE_ENCRYPTION_KEY"
  [helix-chain-bridge-key]="HELIX_CHAIN_BRIDGE_KEY"
  [pinata-api-key]="PINATA_API_KEY"
  [pinata-secret]="PINATA_SECRET"
  [pinata-jwt]="PINATA_JWT"
  [resend-api-key]="RESEND_API_KEY"
  [cf-access-client-id]="CLOUDFLARE_ACCESS_CLIENT_ID"
  [cf-access-client-secret]="CLOUDFLARE_ACCESS_CLIENT_SECRET"
  [cloudflare-api-token]="CLOUDFLARE_API_TOKEN"
  [sentry-dsn]="SENTRY_DSN"
  [notion-api-key]="NOTION_API_KEY"
  [telegram-bot-token]="TELEGRAM_BOT_TOKEN"
  [qn-solana-rpc]="QUICKNODE_SOLANA_RPC_URL"
  [quicknode-api-key]="QUICKNODE_API_KEY"
  [solana-rpc-url]="SOLANA_RPC_URL"
  [helius-api-key]="HELIUS_API_KEY"
  [jupiter-api-key]="JUPITER_API_KEY"
  [infura-project-id]="INFURA_PROJECT_ID"
  [infura-api-key]="INFURA_API_KEY"
  [infura-sol-mainnet-rpc]="INFURA_SOL_MAINNET_RPC"
  [ankr-api-key]="ANKR_API_KEY"
  [ankr-rpc-multichain]="ANKR_RPC_MULTICHAIN"
  [tenderly-api-key]="TENDERLY_API_KEY"
  [tenderly-project]="TENDERLY_PROJECT"
  [tenderly-project-url]="TENDERLY_PROJECT_URL"
  [apn-mint-address]="APN_MINT_ADDRESS"
  [pump-fun-coin-id]="PUMP_FUN_COIN_ID"
)

SECRET_ORDER=(
  agentswarm-master-key
  kimiclaw-consensus-key
  grok-api-key
  openai-api-key
  gemini-api-key
  openrouter-api-key
  tee-signing-key
  database-encryption-key
  helix-chain-bridge-key
  pinata-api-key
  pinata-secret
  pinata-jwt
  resend-api-key
  cf-access-client-id
  cf-access-client-secret
  cloudflare-api-token
  sentry-dsn
  notion-api-key
  telegram-bot-token
  qn-solana-rpc
  quicknode-api-key
  solana-rpc-url
  helius-api-key
  jupiter-api-key
  infura-project-id
  infura-api-key
  infura-sol-mainnet-rpc
  ankr-api-key
  ankr-rpc-multichain
  tenderly-api-key
  tenderly-project
  tenderly-project-url
  apn-mint-address
  pump-fun-coin-id
)

should_inject() {
  local name="$1"
  if [[ -z "${ONLY_FILTER}" ]]; then
    return 0
  fi
  local IFS=,
  local item
  for item in ${ONLY_FILTER}; do
    if [[ "${item}" == "${name}" ]]; then
      return 0
    fi
  done
  return 1
}

VAULT_NAME="${AZURE_KEYVAULT_NAME:-}"
if [[ -z "${VAULT_NAME}" ]]; then
  read -r -p "Azure Key Vault name: " VAULT_NAME
fi
if [[ -z "${VAULT_NAME}" ]]; then
  echo "AZURE_KEYVAULT_NAME is required." >&2
  exit 1
fi

if (( DRY_RUN == 0 )); then
  if ! command -v az >/dev/null 2>&1; then
    echo "Azure CLI (az) is required. Install: https://learn.microsoft.com/cli/azure/install-azure-cli" >&2
    exit 1
  fi
  if ! az account show >/dev/null 2>&1; then
    echo "Not logged in to Azure. Run: az login" >&2
    exit 1
  fi
fi

echo "Initializing secure Key Vault injection (vault: ${VAULT_NAME})..."
echo "Values are never echoed. Press Enter to skip a secret."
echo ""

injected=0
skipped=0
failed=0

for SECRET in "${SECRET_ORDER[@]}"; do
  should_inject "${SECRET}" || continue
  LABEL="${SECRET_LABELS[$SECRET]:-$SECRET}"

  if (( DRY_RUN == 1 )); then
    echo "[dry-run] would inject: ${SECRET} (${LABEL})"
    continue
  fi

  read -rsp "Enter value for ${SECRET} [${LABEL}] (Enter=skip): " SECRET_VAL
  echo ""

  if [[ -z "${SECRET_VAL}" ]]; then
    echo "Skipped ${SECRET}."
    ((skipped+=1)) || true
    continue
  fi

  # Write via stdin to avoid value appearing in argv / shell history
  if printf '%s' "${SECRET_VAL}" | az keyvault secret set \
      --vault-name "${VAULT_NAME}" \
      --name "${SECRET}" \
      --file /dev/stdin \
      --output none 2>/dev/null; then
    echo "Secret [${SECRET}] encrypted and stored."
    ((injected+=1)) || true
  else
    echo "Failed to vault secret [${SECRET}]. Check RBAC: Key Vault Secrets Officer." >&2
    ((failed+=1)) || true
  fi

  unset SECRET_VAL
done

echo ""
if (( DRY_RUN == 1 )); then
  echo "Dry run complete. No secrets were written."
else
  echo "Injection complete. injected=${injected} skipped=${skipped} failed=${failed}"
  echo "Runtime: use DefaultAzureCredential + @azure/keyvault-secrets (see Phase 2 bridge)."
fi
