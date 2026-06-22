#!/usr/bin/env bash
# Verify Unstoppable Domains records via UD API (UD_API_KEY from Vault or env).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REGISTRY="${ROOT}/config/domains/registry.json"
DOMAIN="${1:-yieldswarm.crypto}"

# shellcheck source=scripts/lib/vault-env.sh
source "${ROOT}/scripts/lib/vault-env.sh" 2>/dev/null || true

if [[ -z "${UD_API_KEY:-}" && -n "${VAULT_ADDR:-}" && -n "${VAULT_TOKEN:-}" ]] && command -v vault >/dev/null; then
  UD_API_KEY="$(vault kv get -field=api_key "${VAULT_KV_MOUNT:-yieldswarm}/integrations/unstoppable" 2>/dev/null || true)"
  export UD_API_KEY
fi

[[ -n "${UD_API_KEY:-}" ]] || {
  echo "UD_API_KEY not set — seed Vault integrations/unstoppable or export from vault-export" >&2
  exit 1
}

echo "Resolving ${DOMAIN} via Unstoppable Domains API…"
body="$(mktemp)"
http_code="$(
  curl -fsS -o "$body" -w '%{http_code}' \
    "https://api.unstoppabledomains.com/resolve/domains/${DOMAIN}" \
    -H "Authorization: Bearer ${UD_API_KEY}" \
    -H "Accept: application/json" 2>/dev/null || echo "000"
)"

if [[ "$http_code" != "200" ]]; then
  echo "FAIL HTTP ${http_code}" >&2
  cat "$body" >&2 || true
  exit 1
fi

if command -v jq >/dev/null; then
  jq . "$body"
  website="$(jq -r '.records.ipfs // .records.crypto // .meta.hostedZone // empty' "$body" 2>/dev/null || true)"
  echo "---"
  echo "Domain: ${DOMAIN}"
  [[ -n "$website" ]] && echo "Resolved payload present (inspect JSON above)"
else
  cat "$body"
fi

echo "OK — ${DOMAIN}"
