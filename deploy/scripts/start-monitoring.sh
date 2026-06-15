#!/usr/bin/env bash
# =============================================================================
# STEP 5a — Start the monitoring stack (Prometheus + Grafana + Alertmanager).
#
#   deploy/scripts/start-monitoring.sh [up|down|status]   (default: up)
#
# Regenerates Prometheus targets from the live worker URLs, then brings up the
# compose stack. Wires ERROR_WEBHOOK (app .env) into Alertmanager if present.
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

ACTION="${1:-up}"
MON_DIR="${REPO_ROOT}/$(dirname "${MONITORING_COMPOSE}")"
COMPOSE_FILE="${REPO_ROOT}/${MONITORING_COMPOSE}"

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" "$@"
  elif have docker-compose; then
    docker-compose -f "$COMPOSE_FILE" "$@"
  else
    die "docker compose not available"
  fi
}

gen_targets() {
  step "Regenerating Prometheus targets from worker URLs"
  # Source worker URLs from the generated frontend config or the lease.
  local -a hosts=()
  local cfg="${REPO_ROOT}/${FRONTEND_CONFIG_OUT}"
  if [[ -f "$cfg" ]]; then
    while IFS= read -r h; do [[ -n "$h" ]] && hosts+=("$h"); done < <(
      python3 - "$cfg" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
m = re.search(r'workerUrls:\s*(\[[^\]]*\])', txt)
if m:
    import json
    try:
        for u in json.loads(m.group(1)):
            u = u.replace("https://","").replace("http://","").rstrip("/")
            if u: print(u if ":" in u else u + ":443")
    except Exception:
        pass
PY
    )
  fi

  python3 - "${MON_DIR}/targets.json" "${hosts[@]}" <<'PY'
import json, sys
out = sys.argv[1]
hosts = sys.argv[2:]
json.dump([{"labels": {"service": "yieldswarm-worker"}, "targets": hosts}], open(out, "w"), indent=2)
print(f"wrote {len(hosts)} target(s) -> {out}")
PY
  ok "targets.json updated"
}

wire_alert_webhook() {
  if [[ -n "${ERROR_WEBHOOK:-}" ]]; then
    log "ERROR_WEBHOOK detected — set it as the Alertmanager receiver manually or via env"
  fi
}

main() {
  step "STEP 5a — Monitoring stack (${ACTION})"
  require docker
  case "$ACTION" in
    up)
      gen_targets
      wire_alert_webhook
      compose up -d
      ok "Prometheus:  http://localhost:${PROMETHEUS_PORT}"
      ok "Grafana:     http://localhost:${GRAFANA_PORT} (admin/${GRAFANA_PASSWORD:-yieldswarm})"
      ok "Alertmanager: http://localhost:9093"
      ;;
    down)   compose down ;;
    status) compose ps ;;
    *)      die "unknown action: ${ACTION} (up|down|status)" ;;
  esac
  ok "STEP 5a complete"
}

main "$@"
