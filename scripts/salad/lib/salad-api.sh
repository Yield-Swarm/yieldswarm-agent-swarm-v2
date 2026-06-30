#!/usr/bin/env bash
# Salad Cloud API helpers — never hardcode API keys.
set -euo pipefail

SALAD_API_BASE="${SALAD_API_BASE:-https://api.salad.com/api/public}"

salad_api() {
  local method="$1"
  local path="$2"
  local data="${3:-}"
  local curl_args=(-sS -X "${method}" -H "Salad-Api-Key: ${SALAD_API_KEY}" -H "accept: application/json")
  if [[ -n "${data}" ]]; then
    curl_args+=(-H "content-type: application/json" --data "${data}")
  fi
  curl "${curl_args[@]}" "${SALAD_API_BASE}${path}"
}

salad_require_key() {
  if [[ -z "${SALAD_API_KEY:-}" ]]; then
    echo "[salad] ERROR: set SALAD_API_KEY (store in Vault: yieldswarm/cloud/salad)" >&2
    exit 1
  fi
}

salad_validate_key() {
  salad_require_key
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" -H "Salad-Api-Key: ${SALAD_API_KEY}" \
    "${SALAD_API_BASE}/organizations/probe-invalid-org/gpu-classes")"
  if [[ "${code}" == "401" ]]; then
    echo "[salad] ERROR: invalid SALAD_API_KEY (401)" >&2
    exit 1
  fi
  echo "[salad] API key accepted"
}

salad_require_org_project() {
  if [[ -z "${SALAD_ORGANIZATION:-}" || -z "${SALAD_PROJECT:-}" ]]; then
    cat >&2 <<'EOF'
[salad] ERROR: set SALAD_ORGANIZATION and SALAD_PROJECT

Find them in the Salad portal URL:
  https://portal.salad.com/organizations/<ORG>/projects/<PROJECT>

Or: Organization Settings → copy the organization slug.
EOF
    exit 1
  fi
}

salad_list_gpu_classes() {
  salad_api GET "/organizations/${SALAD_ORGANIZATION}/gpu-classes"
}

salad_create_container() {
  local payload="$1"
  salad_api POST "/organizations/${SALAD_ORGANIZATION}/projects/${SALAD_PROJECT}/containers" "${payload}"
}

salad_start_container() {
  local name="$1"
  salad_api POST "/organizations/${SALAD_ORGANIZATION}/projects/${SALAD_PROJECT}/containers/${name}/start"
}

salad_get_container() {
  local name="$1"
  salad_api GET "/organizations/${SALAD_ORGANIZATION}/projects/${SALAD_PROJECT}/containers/${name}"
}
