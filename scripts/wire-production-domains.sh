#!/usr/bin/env bash
# Wire all 17 production subdomains (9 frontend + 8 backend) per docs/HELIX_SINGLE_PANE.md.
#
# Requires (from Vault or env):
#   UD_API_KEY              — Unstoppable Domains API (optional)
#   CLOUDFLARE_API_TOKEN    — Cloudflare DNS (optional)
#   CLOUDFLARE_ZONE_ID      — Cloudflare zone
#   VERCEL_TOKEN            — attach domains + redeploy
#   ROOT_DOMAIN             — e.g. yieldswarm.crypto
#
# Usage:
#   ./scripts/wire-production-domains.sh [--dry-run]
#   ROOT_DOMAIN=yieldswarm.crypto ./scripts/wire-production-domains.sh
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

# shellcheck source=scripts/lib/vault-env.sh
source "${ROOT}/scripts/lib/vault-env.sh" 2>/dev/null || true

[[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a

ROOT_DOMAIN="${ROOT_DOMAIN:-yieldswarm.crypto}"
VERCEL_CNAME="${VERCEL_CNAME:-cname.vercel-dns.com}"
LEASE_ENV="${ROOT}/.run/akash-lease.env"

if [[ -f "$LEASE_ENV" ]]; then
  # shellcheck disable=SC1090
  source "$LEASE_ENV"
fi

# Derive Akash worker hostname from lease URLs
AKASH_HOST=""
if [[ -n "${AKASH_WORKER_URLS:-}" ]]; then
  AKASH_HOST="$(echo "${AKASH_WORKER_URLS}" | cut -d, -f1 | sed -E 's#^https?://([^/:]+).*#\1#')"
fi
AKASH_HOST="${AKASH_HOST:-${AKASH_WORKER_HOST:-}}"

log() { echo "[$(date -u +%FT%TZ)] [wire-domains] $*" >&2; }
warn() { log "WARN: $*"; }

# 9 frontend zones → Vercel
FRONTEND_ZONES=(app arena portal kairo dashboard council staging docs)
# 8 backend zones → Akash / Cloudflare proxy
BACKEND_ZONES=(api kairo-api helix vault odysseus sovereign cdn monitor)

declare -A RECORDS=()
RECORDS["@"]="vercel:${VERCEL_CNAME}"
for z in "${FRONTEND_ZONES[@]}"; do
  RECORDS["${z}"]="vercel:${VERCEL_CNAME}"
done
for z in "${BACKEND_ZONES[@]}"; do
  if [[ -n "$AKASH_HOST" ]]; then
    RECORDS["${z}"]="cname:${AKASH_HOST}"
  else
    RECORDS["${z}"]="cname:pending-akash-lease"
  fi
done

wire_cloudflare() {
  local host="$1" type="$2" value="$3"
  local name="${host}"
  [[ "$host" == "@" ]] && name="${ROOT_DOMAIN}"

  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ZONE_ID:-}" ]]; then
    warn "Cloudflare credentials missing — skip ${host}.${ROOT_DOMAIN}"
    return 0
  fi

  local cf_name="$host"
  [[ "$host" == "@" ]] && cf_name="${ROOT_DOMAIN}"

  log "Cloudflare ${type} ${cf_name} → ${value}"
  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi

  curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -nc --arg type "$type" --arg name "$cf_name" --arg content "$value" \
      '{type:$type,name:$name,content:$content,proxied:true,ttl:1}')" \
    >/dev/null || warn "Cloudflare upsert failed for ${cf_name}"
}

wire_vercel_domain() {
  local subdomain="$1"
  local fqdn="${subdomain}.${ROOT_DOMAIN}"
  [[ "$subdomain" == "@" ]] && fqdn="${ROOT_DOMAIN}"

  if [[ -z "${VERCEL_TOKEN:-}" || -z "${VERCEL_PROJECT_ID:-}" ]]; then
    warn "VERCEL_TOKEN/VERCEL_PROJECT_ID missing — skip ${fqdn}"
    return 0
  fi

  log "Vercel attach domain ${fqdn}"
  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi

  curl -fsS -X POST "https://api.vercel.com/v10/projects/${VERCEL_PROJECT_ID}/domains" \
    -H "Authorization: Bearer ${VERCEL_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -nc --arg name "$fqdn" '{name:$name}')" \
    >/dev/null || warn "Vercel domain attach failed for ${fqdn}"
}

main() {
  log "Wiring 17 domains on ${ROOT_DOMAIN} (dry_run=${DRY_RUN})"
  log "Akash backend host: ${AKASH_HOST:-unset}"

  if [[ -n "${VAULT_ADDR:-}" && -n "${VAULT_TOKEN:-}" ]]; then
    vault_export_env kv/data/yieldswarm/domains/runtime 2>/dev/null || true
  fi

  local host spec kind target
  for host in "@" "${FRONTEND_ZONES[@]}" "${BACKEND_ZONES[@]}"; do
    spec="${RECORDS[$host]}"
    kind="${spec%%:*}"
    target="${spec#*:}"
    case "$kind" in
      vercel)
        wire_vercel_domain "$host"
        wire_cloudflare "$host" CNAME "$target"
        ;;
      cname)
        wire_cloudflare "$host" CNAME "$target"
        ;;
    esac
  done

  log "17-domain wiring pass complete — verify with: dig app.${ROOT_DOMAIN}"
}

main "$@"
