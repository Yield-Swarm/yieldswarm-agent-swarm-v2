#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/usr/local/lib/yieldswarm/vault-env.sh
. /usr/local/lib/yieldswarm/vault-env.sh

runtime_secret_path="${ODYSSEUS_RUNTIME_VAULT_PATH:-${VAULT_KV_PATH:-yieldswarm/data/odysseus/runtime}}"

echo "Loading Odysseus runtime configuration from HashiCorp Vault path ${runtime_secret_path}" >&2
vault_export_env "$runtime_secret_path"

required_runtime_keys=(
  ODYSSEUS_API_KEY
  ODYSSEUS_MODEL_HOST
  ODYSSEUS_MODEL_API_KEY
)

missing_keys=()
for key in "${required_runtime_keys[@]}"; do
  if [ -z "${!key:-}" ]; then
    missing_keys+=("$key")
  fi
done

if [ "${#missing_keys[@]}" -gt 0 ]; then
  printf 'Missing required Odysseus Vault keys: %s\n' "${missing_keys[*]}" >&2
  exit 1
fi

exec "$@"
