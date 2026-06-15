#!/usr/bin/env bash
set -Eeuo pipefail

timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log() {
  echo "[$(timestamp)] [entrypoint] $*"
}

fail() {
  echo "[$(timestamp)] [entrypoint] ERROR: $*" >&2
  exit 1
}

on_error() {
  local line_number="$1"
  local exit_code="$2"
  echo "[$(timestamp)] [entrypoint] ERROR: command failed at line ${line_number} (exit ${exit_code})" >&2
}

wait_for_endpoint() {
  local endpoint="$1"
  local timeout_seconds="$2"
  local host="${endpoint%:*}"
  local port="${endpoint##*:}"
  local start_time

  if [[ "${host}" == "${port}" ]]; then
    fail "invalid WAIT_FOR_HOSTS endpoint '${endpoint}' (expected host:port)"
  fi

  start_time="$(date +%s)"
  while true; do
    if bash -c ">/dev/tcp/${host}/${port}" 2>/dev/null; then
      log "dependency ${host}:${port} is reachable"
      return 0
    fi

    if (( "$(date +%s)" - start_time >= timeout_seconds )); then
      fail "timed out waiting for ${host}:${port} after ${timeout_seconds}s"
    fi

    sleep 2
  done
}

trap 'on_error "${LINENO}" "$?"' ERR

APP_ROOT="${APP_ROOT:-/app}"
WORKER_STATE_DIR="${WORKER_STATE_DIR:-/var/lib/yieldswarm}"
WORKER_CACHE_DIR="${WORKER_CACHE_DIR:-/var/cache/yieldswarm}"
WORKER_LOG_DIR="${WORKER_LOG_DIR:-/var/log/yieldswarm}"
WAIT_FOR_TIMEOUT_SECONDS="${WAIT_FOR_TIMEOUT_SECONDS:-60}"

mkdir -p "${WORKER_STATE_DIR}" "${WORKER_CACHE_DIR}" "${WORKER_LOG_DIR}"
cd "${APP_ROOT}"

if [[ -n "${WAIT_FOR_HOSTS:-}" ]]; then
  IFS=',' read -r -a endpoints <<< "${WAIT_FOR_HOSTS}"
  for endpoint in "${endpoints[@]}"; do
    wait_for_endpoint "${endpoint}" "${WAIT_FOR_TIMEOUT_SECONDS}"
  done
fi

if [[ "${RUN_MIGRATIONS:-0}" == "1" ]]; then
  if [[ -z "${MIGRATIONS_CMD:-}" ]]; then
    fail "RUN_MIGRATIONS=1 requires MIGRATIONS_CMD"
  fi
  log "running database migrations"
  bash -lc "${MIGRATIONS_CMD}"
fi

if [[ "$#" -eq 0 ]]; then
  set -- python -m worker
fi

term_handler() {
  log "received termination signal, forwarding to child process"
  if [[ -n "${child_pid:-}" ]]; then
    kill -TERM "${child_pid}" 2>/dev/null || true
  fi
}

trap term_handler SIGINT SIGTERM

log "starting worker command: $*"
"$@" &
child_pid="$!"
wait "${child_pid}"
exit_code="$?"
log "worker exited with code ${exit_code}"
exit "${exit_code}"
