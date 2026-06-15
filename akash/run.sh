#!/usr/bin/env bash
#
# run.sh - convenience wrapper to run lease-manager.py as a background process
# without systemd. Provides start/stop/status/restart/foreground/logs.
#
#   ./run.sh start       # launch in the background (nohup) and write a pidfile
#   ./run.sh stop        # graceful shutdown (SIGTERM)
#   ./run.sh status      # report whether the manager is running
#   ./run.sh restart
#   ./run.sh foreground  # run in the foreground (Ctrl-C to stop)
#   ./run.sh once        # single reconcile pass (same as cron mode)
#   ./run.sh logs        # tail the log file
#
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${PYTHON:-python3}"
MANAGER="$SCRIPT_DIR/lease-manager.py"

# Load .env so PIDFILE / LOG paths match what the manager uses.
for f in "$SCRIPT_DIR/.env" "$SCRIPT_DIR/../.env"; do
  [[ -f "$f" ]] && { set -a; # shellcheck disable=SC1090
    source "$f"; set +a; }
done

STATE_DIR="$SCRIPT_DIR/state"
PIDFILE="${LEASE_MANAGER_PIDFILE:-$STATE_DIR/lease-manager.pid}"
LOGFILE="${LEASE_MANAGER_LOG:-$STATE_DIR/lease-manager.log}"

mkdir -p "$STATE_DIR"

is_running() {
  [[ -f "$PIDFILE" ]] || return 1
  local pid; pid="$(cat "$PIDFILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

case "${1:-}" in
  start)
    if is_running; then
      echo "lease-manager already running (pid $(cat "$PIDFILE"))"; exit 0
    fi
    echo "starting lease-manager in background..."
    LEASE_MANAGER_LOG="$LOGFILE" nohup "$PY" "$MANAGER" >>"$LOGFILE" 2>&1 &
    sleep 1
    if is_running; then
      echo "started (pid $(cat "$PIDFILE")), logs: $LOGFILE"
    else
      echo "failed to start; check $LOGFILE"; exit 1
    fi
    ;;
  stop)
    if ! is_running; then echo "not running"; exit 0; fi
    pid="$(cat "$PIDFILE")"
    echo "stopping lease-manager (pid $pid)..."
    kill -TERM "$pid" 2>/dev/null || true
    for _ in $(seq 1 30); do is_running || break; sleep 1; done
    is_running && { echo "force killing"; kill -KILL "$pid" 2>/dev/null || true; }
    rm -f "$PIDFILE"
    echo "stopped"
    ;;
  restart)
    "$0" stop || true
    "$0" start
    ;;
  status)
    if is_running; then
      echo "running (pid $(cat "$PIDFILE"))"
      "$PY" "$MANAGER" --status
    else
      echo "not running"; exit 3
    fi
    ;;
  foreground)
    exec "$PY" "$MANAGER"
    ;;
  once)
    exec "$PY" "$MANAGER" --once
    ;;
  logs)
    exec tail -f "$LOGFILE"
    ;;
  *)
    echo "usage: $0 {start|stop|restart|status|foreground|once|logs}"; exit 1
    ;;
esac
