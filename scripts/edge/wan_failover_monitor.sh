#!/usr/bin/env bash
# wan_failover_monitor.sh — WAN / multi-AZ link health audit (real probes, not simulated ERPS)
#
# Usage:
#   WAN_TARGETS="us-west-2.amazonaws.com,1.1.1.1" ./scripts/edge/wan_failover_monitor.sh
set -euo pipefail

LOG_DIR="${YIELDSWARM_LOG_DIR:-$HOME/yieldswarm-logs}"
TARGETS="${WAN_TARGETS:-us-west-2.amazonaws.com,8.8.8.8,192.168.1.1}"
POLL_MS="${WAN_POLL_INTERVAL_MS:-3300}"
FAIL_THRESHOLD_MS="${WAN_RTT_FAIL_MS:-165}"

log() { printf '[wan-monitor] %s\n' "$*" >&2; }

mkdir -p "${LOG_DIR}"
log "Task 4 — WAN routing audit (targets=${TARGETS})"

IFS=',' read -ra HOSTS <<< "${TARGETS}"
fail=0

for host in "${HOSTS[@]}"; do
  host="${host// /}"
  [[ -n "${host}" ]] || continue
  if command -v ping >/dev/null 2>&1; then
    if ping -c 2 -W 2 "${host}" >/tmp/wan_ping.txt 2>&1; then
      rtt="$(grep -oE 'rtt min/avg/max[^=]*= [0-9.]+' /tmp/wan_ping.txt | awk '{print $4}' || echo '?')"
      log "PASS ${host} avg_rtt_ms=${rtt}"
      if [[ "${rtt}" != "?" ]] && python3 -c "exit(0 if float('${rtt}') < ${FAIL_THRESHOLD_MS} else 1)" 2>/dev/null; then
        : ok
      elif [[ "${rtt}" != "?" ]]; then
        log "WARN ${host} rtt ${rtt}ms > ${FAIL_THRESHOLD_MS}ms threshold"
        fail=1
      fi
    else
      log "FAIL ${host} unreachable"
      fail=1
    fi
  else
    log "WARN: ping not available — skip ${host}"
  fi
  sleep "$(python3 -c "print(${POLL_MS}/1000/len('${TARGETS}'.split(',')))" 2>/dev/null || echo 0.1)"
done

{
  echo "wan_audit $(date -u +%Y-%m-%dT%H:%M:%SZ) fail=${fail}"
} >>"${LOG_DIR}/wan_routing.log"

log "complete — fail=${fail}"
exit "${fail}"
