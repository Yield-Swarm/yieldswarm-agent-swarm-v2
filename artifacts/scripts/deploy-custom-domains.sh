#!/usr/bin/env bash
# =============================================================================
# deploy-custom-domains.sh — Pillar-scoped custom domain + SSL + telemetry anchor
#
# DOMAIN_MATRIX format: "fqdn:pillar_id:service_name"
#
# Usage:
#   ./artifacts/scripts/deploy-custom-domains.sh --dry-run
#   DOMAIN_ROOT=yieldswarm.crypto ./artifacts/scripts/deploy-custom-domains.sh
# =============================================================================
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/lib/vault-env.sh
source "${ROOT}/scripts/lib/vault-env.sh" 2>/dev/null || true
[[ -f deploy/config.env ]] && set -a && source deploy/config.env && set +a
[[ -f .env ]] && set -a && source .env && set +a

DOMAIN_ROOT="${DOMAIN_ROOT:-${ROOT_DOMAIN:-yieldswarm.crypto}}"
AKASH_BERT_INGRESS_URL="${AKASH_BERT_INGRESS_URL:-https://9pktq0lijpeij3bm3gfj02q7fo.ingress.h4i-dedicated.eu-sw-2.digitalfrontier.so}"
DRY_RUN=0
RUN_DIR="${RUN_DIR:-${ROOT}/.run}"

# Expand DOMAIN_ROOT in matrix entries at runtime
DOMAIN_MATRIX=(
  "bert.${DOMAIN_ROOT}:04_akash_gpu_workers:bert-flask-inference"
)

log()  { echo "[$(date -u +%FT%TZ)] [deploy-custom-domains] $*" >&2; }
warn() { log "WARN: $*"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) shift ;;
  esac
done

mkdir -p "$RUN_DIR"

ingress_host() {
  echo "${AKASH_BERT_INGRESS_URL}" | sed -E 's#^https?://([^/:]+).*#\1#'
}

wire_cloudflare_cname() {
  local subdomain="$1" target="$2"
  local fqdn="${subdomain}.${DOMAIN_ROOT}"
  [[ "$subdomain" == "@" ]] && fqdn="${DOMAIN_ROOT}"

  if [[ -z "${CLOUDFLARE_API_TOKEN:-}" || -z "${CLOUDFLARE_ZONE_ID:-}" ]]; then
    warn "Cloudflare credentials missing — skip ${fqdn} → ${target}"
    return 0
  fi

  log "Cloudflare CNAME ${fqdn} → ${target} (proxied, SSL edge)"
  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi

  curl -fsS -X POST "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "$(jq -nc --arg name "$fqdn" --arg content "$target" \
      '{type:"CNAME",name:$name,content:$content,proxied:true,ttl:1}')" \
    >/dev/null || warn "Cloudflare upsert failed for ${fqdn}"
}

telemetry_anchor() {
  local pillar="$1" service="$2" fqdn="$3"
  log "Telemetry anchor ${pillar}/${service} @ ${fqdn}"

  if [[ "$DRY_RUN" == "1" ]]; then return 0; fi

  node --input-type=module -e "
    import { pulseGpuTelemetry } from './src/infrastructure/telemetry-validation-bridge.js';
    import { logPillarTelemetry } from './src/infrastructure/pillar-telemetry-log.js';
    import fs from 'node:fs';
    const r = pulseGpuTelemetry({ pillarId: '${pillar}', vramUsedGb: 0.5, tempC: 40, utilizationPct: 5, gpuId: 'domain-anchor' });
    logPillarTelemetry('${pillar}', 'custom_domain_deployed', { fqdn: '${fqdn}', service: '${service}' });
    fs.appendFileSync('${RUN_DIR}/custom-domain-anchors.jsonl', JSON.stringify({ fqdn: '${fqdn}', pillar: '${pillar}', service: '${service}', block: r.auditBlock.blockVerificationHash, at: new Date().toISOString() }) + '\n');
  " 2>/dev/null || warn "telemetry anchor node pulse skipped"
}

declare -a DEPLOYED=()

main() {
  local target
  target="$(ingress_host)"
  log "Deploying ${#DOMAIN_MATRIX[@]} custom domain(s) on ${DOMAIN_ROOT} (dry_run=${DRY_RUN})"
  log "Akash BERT ingress target: ${target}"

  local entry fqdn pillar service subdomain
  for entry in "${DOMAIN_MATRIX[@]}"; do
    fqdn="${entry%%:*}"
    local rest="${entry#*:}"
    pillar="${rest%%:*}"
    service="${rest#*:}"

    subdomain="${fqdn%%.${DOMAIN_ROOT}}"
    [[ "$subdomain" == "$fqdn" ]] && subdomain="@"

    wire_cloudflare_cname "$subdomain" "$target"
    telemetry_anchor "$pillar" "$service" "$fqdn"

    DEPLOYED+=("$(jq -nc --arg fqdn "$fqdn" --arg pillar "$pillar" --arg service "$service" --arg target "$target" \
      '{fqdn:$fqdn, pillar:$pillar, service:$service, cname_target:$target, ssl:"cloudflare_edge"}')")
  done

  printf '%s\n' "${DEPLOYED[@]}" | jq -s \
    --arg domain_root "$DOMAIN_ROOT" \
    --argjson dry_run "$DRY_RUN" \
    '{domain_root:$domain_root, dry_run:$dry_run, domains:.}' \
    > "${RUN_DIR}/custom-domains-deploy.json"

  log "Wrote ${RUN_DIR}/custom-domains-deploy.json"
  jq '.' "${RUN_DIR}/custom-domains-deploy.json"
}

main "$@"
