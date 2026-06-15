#!/usr/bin/env bash
# Container-level healthcheck.
#   * vault-agent must be running
#   * rendered env file must exist + be readable + non-empty + recently modified
#   * application PID must be alive
set -Eeuo pipefail

ENV_FILE="${APP_ENV_FILE:-/run/vault-agent/app.env}"
AGENT_PID_FILE="/run/vault-agent/agent.pid"
APP_PID_FILE="/run/vault-agent/app.pid"
MAX_RENDER_AGE_SECS="${MAX_RENDER_AGE_SECS:-3600}"

check_pid() {
  local f="$1" name="$2"
  [[ -r "$f" ]] || { echo "unhealthy: missing $name pid file ($f)"; exit 1; }
  local pid; pid="$(<"$f")"
  kill -0 "$pid" 2>/dev/null || { echo "unhealthy: $name pid $pid not running"; exit 1; }
}

check_pid "$AGENT_PID_FILE" "vault-agent"
check_pid "$APP_PID_FILE"   "app"

[[ -s "$ENV_FILE" ]] || { echo "unhealthy: $ENV_FILE missing or empty"; exit 1; }

now=$(date +%s)
mtime=$(stat -c %Y "$ENV_FILE")
age=$(( now - mtime ))
if (( age > MAX_RENDER_AGE_SECS )); then
  echo "unhealthy: $ENV_FILE last rendered ${age}s ago (max ${MAX_RENDER_AGE_SECS})"
  exit 1
fi

echo "ok: agent + app running, env rendered ${age}s ago"
