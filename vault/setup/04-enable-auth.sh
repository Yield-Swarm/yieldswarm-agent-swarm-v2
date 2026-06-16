#!/usr/bin/env bash
# vault/setup/04-enable-auth.sh
#
# Enable AppRole and create one role per workload. Returns the role_id
# of each role to stdout as JSON for downstream consumption.
#
# SecretIDs are NOT minted here - they're response-wrapped on demand by
# CI/admin tooling using the ci-bootstrap policy and `vault write -wrap-ttl=...`.
#
# Optional:
#   ENABLE_OIDC=true OIDC_DISCOVERY_URL=... OIDC_CLIENT_ID=... OIDC_CLIENT_SECRET=...
#   ENABLE_K8S=true  K8S_HOST=...           K8S_CA_CERT=...    K8S_JWT=...
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${HERE}/lib.sh"
require_token

# ---- AppRole ------------------------------------------------------------
ensure_auth approle

create_or_update_role() {
  local name="$1"; shift
  log "Configuring AppRole role '${name}'"
  vault write -f "auth/approle/role/${name}" "$@" >/dev/null
  role_id="$(vault read -field=role_id "auth/approle/role/${name}/role-id")"
  printf '  role_id(%s) = %s\n' "${name}" "${role_id}"
}

# Terraform: short tokens, no SecretID re-use, capped uses for safety
create_or_update_role terraform \
  token_policies="terraform" \
  token_ttl="30m" \
  token_max_ttl="2h" \
  token_num_uses=0 \
  secret_id_ttl="10m" \
  secret_id_num_uses=1 \
  bind_secret_id=true

# Akash runtime: longer-lived because Akash leases run for hours/days.
# CIDR-pin to Akash provider egress IPs by overriding APPROLE_AKASH_CIDRS.
create_or_update_role akash-runtime \
  token_policies="akash-runtime" \
  token_ttl="1h" \
  token_max_ttl="24h" \
  token_num_uses=0 \
  secret_id_ttl="30m" \
  secret_id_num_uses=1 \
  bind_secret_id=true \
  secret_id_bound_cidrs="${APPROLE_AKASH_CIDRS:-0.0.0.0/0}" \
  token_bound_cidrs="${APPROLE_AKASH_CIDRS:-0.0.0.0/0}"

# Long-lived agent shards (Vercel, Azure, MacBook)
create_or_update_role agent-runtime \
  token_policies="agent-runtime" \
  token_ttl="4h" \
  token_max_ttl="72h" \
  token_num_uses=0 \
  secret_id_ttl="1h" \
  secret_id_num_uses=1 \
  bind_secret_id=true

# CI/Bootstrap role - allowed to mint wrapped SecretIDs for the above.
create_or_update_role ci-bootstrap \
  token_policies="ci-bootstrap" \
  token_ttl="15m" \
  token_max_ttl="30m" \
  token_num_uses=0 \
  secret_id_ttl="5m" \
  secret_id_num_uses=1 \
  bind_secret_id=true

# Integration backend (Arena API, no GPU) — Akash :8080
create_or_update_role integration-backend \
  token_policies="integration-backend" \
  token_ttl="1h" \
  token_max_ttl="24h" \
  token_num_uses=0 \
  secret_id_ttl="30m" \
  secret_id_num_uses=1 \
  bind_secret_id=true \
  secret_id_bound_cidrs="${APPROLE_AKASH_CIDRS:-0.0.0.0/0}" \
  token_bound_cidrs="${APPROLE_AKASH_CIDRS:-0.0.0.0/0}"

# Bittensor miner on Akash (Ollama + axon) — same CIDR binding as akash-runtime.
create_or_update_role bittensor-runtime \
  token_policies="bittensor-runtime" \
  token_ttl="1h" \
  token_max_ttl="24h" \
  token_num_uses=0 \
  secret_id_ttl="30m" \
  secret_id_num_uses=1 \
  bind_secret_id=true \
  secret_id_bound_cidrs="${APPROLE_AKASH_CIDRS:-0.0.0.0/0}" \
  token_bound_cidrs="${APPROLE_AKASH_CIDRS:-0.0.0.0/0}"

# Odysseus full stack (LLM keys at deploy-render time)
create_or_update_role odysseus-runtime \
  token_policies="odysseus-runtime" \
  token_ttl="1h" \
  token_max_ttl="24h" \
  token_num_uses=0 \
  secret_id_ttl="30m" \
  secret_id_num_uses=1 \
  bind_secret_id=true \
  secret_id_bound_cidrs="${APPROLE_AKASH_CIDRS:-0.0.0.0/0}" \
  token_bound_cidrs="${APPROLE_AKASH_CIDRS:-0.0.0.0/0}"

# ---- (Optional) OIDC for human admins ----------------------------------
if [ "${ENABLE_OIDC:-false}" = "true" ]; then
  ensure_auth oidc
  log "Configuring OIDC"
  vault write auth/oidc/config \
    oidc_discovery_url="${OIDC_DISCOVERY_URL}" \
    oidc_client_id="${OIDC_CLIENT_ID}" \
    oidc_client_secret="${OIDC_CLIENT_SECRET}" \
    default_role="admin" >/dev/null
  vault write auth/oidc/role/admin \
    bound_audiences="${OIDC_CLIENT_ID}" \
    allowed_redirect_uris="${OIDC_REDIRECT_URI:-http://localhost:8250/oidc/callback},${VAULT_ADDR}/ui/vault/auth/oidc/oidc/callback" \
    user_claim="sub" \
    token_policies="admin" \
    token_ttl="1h" \
    token_max_ttl="8h" >/dev/null
fi

# ---- (Optional) Kubernetes auth for in-cluster pods --------------------
if [ "${ENABLE_K8S:-false}" = "true" ]; then
  ensure_auth kubernetes
  log "Configuring Kubernetes auth"
  vault write auth/kubernetes/config \
    kubernetes_host="${K8S_HOST}" \
    kubernetes_ca_cert="${K8S_CA_CERT}" \
    token_reviewer_jwt="${K8S_JWT}" >/dev/null
fi

log "Auth methods complete."
