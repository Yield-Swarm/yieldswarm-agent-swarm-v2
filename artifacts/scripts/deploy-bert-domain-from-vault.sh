#!/usr/bin/env bash
# Deploy bert.$DOMAIN_ROOT using Cloudflare credentials from Vault.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/lib/vault-env.sh
source "${ROOT}/scripts/lib/vault-env.sh" 2>/dev/null || true
[[ -f .env ]] && set -a && source .env && set +a
if [[ -z "${VAULT_ADDR:-}" ]]; then
  echo "VAULT_ADDR required for live domain deploy" >&2
  exit 1
fi
vault_export_env kv/data/yieldswarm/integrations/cloudflare
exec "${ROOT}/artifacts/scripts/deploy-custom-domains.sh" "$@"
