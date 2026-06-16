#!/usr/bin/env bash
# Shared Tesla Fleet API helpers (partner token, register, verify).
set -euo pipefail

TESLA_AUTH_URL="${TESLA_AUTH_URL:-https://fleet-auth.prd.vn.cloud.tesla.com/oauth2/v3/token}"
TESLA_SCOPE="${TESLA_SCOPE:-openid vehicle_device_data vehicle_cmds vehicle_charging_cmds vehicle_specs}"

tesla_region_base() {
  case "${1:-na}" in
    na|NA) echo "https://fleet-api.prd.na.vn.cloud.tesla.com" ;;
    eu|EU) echo "https://fleet-api.prd.eu.vn.cloud.tesla.com" ;;
    cn|CN)
      TESLA_AUTH_URL="${TESLA_AUTH_URL_CN:-https://auth.tesla.cn/oauth2/v3/token}"
      echo "https://fleet-api.prd.cn.vn.cloud.tesla.cn"
      ;;
    *) echo "unknown region: $1" >&2; return 1 ;;
  esac
}

tesla_partner_token() {
  local region="${1:-na}"
  local audience client_id client_secret
  audience="$(tesla_region_base "$region")"
  client_id="${TESLA_CLIENT_ID:?TESLA_CLIENT_ID required}"
  client_secret="${TESLA_CLIENT_SECRET:?TESLA_CLIENT_SECRET required}"

  curl -sfS --request POST \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=client_credentials' \
    --data-urlencode "client_id=${client_id}" \
    --data-urlencode "client_secret=${client_secret}" \
    --data-urlencode "scope=${TESLA_SCOPE}" \
    --data-urlencode "audience=${audience}" \
    "${TESLA_AUTH_URL}"
}

tesla_register_domain() {
  local region="${1:-na}"
  local token="${2:?partner token required}"
  local domain="${3:?domain required}"
  local base
  base="$(tesla_region_base "$region")"

  curl -sfS --request POST \
    --header 'Content-Type: application/json' \
    --header "Authorization: Bearer ${token}" \
    --data "{\"domain\":\"${domain}\"}" \
    "${base}/api/1/partner_accounts"
}

tesla_verify_public_key() {
  local region="${1:-na}"
  local token="${2:?partner token required}"
  local domain="${3:?domain required}"
  local base
  base="$(tesla_region_base "$region")"

  curl -sfS --request GET \
    --header "Authorization: Bearer ${token}" \
    "${base}/api/1/partner_accounts/public_key?domain=${domain}"
}
