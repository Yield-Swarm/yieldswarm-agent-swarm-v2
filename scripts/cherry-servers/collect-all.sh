#!/usr/bin/env bash
# Run local host telemetry + cloud API inventory for Cherry Servers packet.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"
mkdir -p "${RUN_DIR}"

LOCAL_JSON="${RUN_DIR}/cherry-servers-local-host.json"
LOCAL_MD="${RUN_DIR}/cherry-servers-local-host.md"

log() { printf '[cherry-collect] %s\n' "$*" >&2; }

log "Collecting local host profile..."
python3 "${REPO_ROOT}/scripts/telemetry/sys_profile.py" --json > "${LOCAL_JSON}"
python3 "${REPO_ROOT}/scripts/telemetry/sys_profile.py" > "${LOCAL_MD}"

ARGS=()
for arg in "$@"; do ARGS+=("$arg"); done

log "Collecting cloud inventory..."
bash "${SCRIPT_DIR}/export-cloud-specs.sh" "${ARGS[@]}"

FULL_JSON="${RUN_DIR}/cherry-servers-full-packet.json"
FULL_MD="${RUN_DIR}/cherry-servers-full-packet.md"

jq -n \
  --slurpfile local "${LOCAL_JSON}" \
  --slurpfile cloud "${RUN_DIR}/cherry-servers-cloud-specs.json" \
  '{
    report_title: "YieldSwarm Full Multi-Cloud + Host Telemetry Packet",
    recipient: "Justas | CherryServers",
    local_host: $local[0],
    cloud: $cloud[0]
  }' > "${FULL_JSON}"

{
  echo "# YieldSwarm — Cherry Servers Full Credits Packet"
  echo ""
  cat "${LOCAL_MD}"
  echo ""
  echo "---"
  echo ""
  cat "${RUN_DIR}/cherry-servers-cloud-specs.md"
} > "${FULL_MD}"

log "Wrote ${FULL_JSON}"
log "Wrote ${FULL_MD}"
