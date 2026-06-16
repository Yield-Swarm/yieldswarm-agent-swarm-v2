#!/usr/bin/env bash
# Join this host to yieldswarm.internal (Route53 private zone or /etc/hosts fallback).
#
# Usage:
#   sudo ./scripts/join-yieldswarm-internal.sh
#   VAULT_HOST=10.0.1.50 sudo ./scripts/join-yieldswarm-internal.sh
#
# Requires one of:
#   - AWS Route53 private hosted zone + ec2 instance IAM role
#   - Manual VAULT_HOST + ARENA_HOST env vars (writes /etc/hosts)
set -euo pipefail

DOMAIN="${YIELDSWARM_INTERNAL_DOMAIN:-yieldswarm.internal}"
VAULT_HOST="${VAULT_HOST:-}"
ARENA_HOST="${ARENA_HOST:-}"
ZONE_ID="${ROUTE53_PRIVATE_ZONE_ID:-}"

log() { echo "[join-internal] $*"; }
die() { log "ERROR: $*"; exit 1; }

write_hosts() {
  local vault_ip="$1"
  local arena_ip="${2:-$vault_ip}"
  log "Writing /etc/hosts entries for ${DOMAIN}"
  grep -q "${DOMAIN}" /etc/hosts 2>/dev/null && {
    log "/etc/hosts already has ${DOMAIN} entries — skipping"
    return 0
  }
  {
    echo "# YieldSwarm internal — added by join-yieldswarm-internal.sh"
    echo "${vault_ip}  vault.${DOMAIN}"
    echo "${arena_ip}  arena.${DOMAIN}"
    echo "${vault_ip}  grafana.${DOMAIN}"
  } | sudo tee -a /etc/hosts >/dev/null
}

resolve_from_route53() {
  [[ -n "${ZONE_ID}" ]] || return 1
  command -v aws &>/dev/null || return 1
  local name
  name="$(aws route53 list-resource-record-sets --hosted-zone-id "${ZONE_ID}" \
    --query "ResourceRecordSets[?Name=='vault.${DOMAIN}.'].ResourceRecords[0].Value" \
    --output text 2>/dev/null || true)"
  [[ -n "${name}" && "${name}" != "None" ]] || return 1
  echo "${name}"
}

main() {
  if [[ "${EUID}" -ne 0 ]] && ! sudo -n true 2>/dev/null; then
    die "run with sudo or as root"
  fi

  local vault_ip="${VAULT_HOST}"
  if [[ -z "${vault_ip}" ]]; then
    vault_ip="$(resolve_from_route53 || true)"
  fi

  if [[ -z "${vault_ip}" ]]; then
    log "No Route53 zone or VAULT_HOST — set manually:"
    log "  export VAULT_HOST=10.x.x.x ARENA_HOST=10.x.x.x"
    log "  sudo -E ./scripts/join-yieldswarm-internal.sh"
    exit 1
  fi

  write_hosts "${vault_ip}" "${ARENA_HOST:-${vault_ip}}"

  log "Joined ${DOMAIN}"
  log "  vault.${DOMAIN} → ${vault_ip}"
  log "Test: curl -sk https://vault.${DOMAIN}:8200/v1/sys/health || curl -s http://vault.${DOMAIN}:8200/v1/sys/health"
}

main "$@"
