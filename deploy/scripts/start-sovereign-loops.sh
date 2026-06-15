#!/usr/bin/env bash
# =============================================================================
# STEP 5b — Start all sovereign loops.
#
#   deploy/scripts/start-sovereign-loops.sh [start|stop|status]  (default: start)
#
# Launches and supervises the long-running background loops that keep the swarm
# sovereign:
#   * sovereign-loop : runs the agents/crons every SOVEREIGN_LOOP_INTERVAL
#   * akash-auto-heal: keeps the Akash lease funded + healthy (if lease exists)
#
# PIDs/logs live under .run/. These are local supervisors; in production the
# same loops run inside the Akash `agents` container and via systemd units
# (see deploy/systemd/).
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
ensure_run_dir

RUN="${REPO_ROOT}/${RUN_DIR}"

start_one() {
  local name="$1"; shift
  local pidf="${RUN}/${name}.pid"
  local logf="${RUN}/${name}.log"
  if [[ -f "$pidf" ]] && kill -0 "$(cat "$pidf")" 2>/dev/null; then
    warn "${name} already running (pid $(cat "$pidf"))"; return
  fi
  nohup "$@" >>"$logf" 2>&1 &
  echo $! > "$pidf"
  ok "started ${name} (pid $(cat "$pidf"), log ${RUN_DIR}/${name}.log)"
}

stop_one() {
  local name="$1"
  local pidf="${RUN}/${name}.pid"
  if [[ -f "$pidf" ]] && kill -0 "$(cat "$pidf")" 2>/dev/null; then
    kill "$(cat "$pidf")" && ok "stopped ${name}"
  else
    log "${name} not running"
  fi
  rm -f "$pidf"
}

status_one() {
  local name="$1"
  local pidf="${RUN}/${name}.pid"
  if [[ -f "$pidf" ]] && kill -0 "$(cat "$pidf")" 2>/dev/null; then
    ok "${name}: running (pid $(cat "$pidf"))"
  else
    warn "${name}: stopped"
  fi
}

do_start() {
  step "STEP 5b — Starting sovereign loops"
  require python3
  export REPO_ROOT RUN_DIR SOVEREIGN_LOOP_INTERVAL
  start_one "sovereign-loop" python3 "${REPO_ROOT}/deploy/runtime/swarm_runner.py"

  if [[ -f "${RUN}/akash-lease.env" ]]; then
    start_one "akash-auto-heal" bash "${REPO_ROOT}/deploy/akash/auto-heal.sh"
  else
    warn "no Akash lease found — skipping auto-heal (run create-lease.sh first)"
  fi
  ok "STEP 5b complete — sovereign loops live"
  echo
  log "Tail logs:  tail -f ${RUN_DIR}/sovereign-loop.log ${RUN_DIR}/akash-auto-heal.log"
}

main() {
  case "${1:-start}" in
    start)  do_start ;;
    stop)   step "Stopping sovereign loops"; stop_one "sovereign-loop"; stop_one "akash-auto-heal" ;;
    status) step "Sovereign loop status"; status_one "sovereign-loop"; status_one "akash-auto-heal" ;;
    *)      die "unknown action: ${1} (start|stop|status)" ;;
  esac
}

main "$@"
