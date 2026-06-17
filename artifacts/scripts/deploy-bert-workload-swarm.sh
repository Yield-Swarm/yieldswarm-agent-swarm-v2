#!/usr/bin/env bash
# BERT Workload Deployment Swarm — route agent memory/RAG tasks to live /predict.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
API="${YIELDSWARM_API_URL:-http://127.0.0.1:8080}"
TENANT="${BERT_SWARM_TENANT_ID:-yieldswarm-default}"
BATCH="${BERT_SWARM_BATCH_SIZE:-5}"

log() { echo "[bert-workload-swarm] $*"; }

light_probe() {
  curl -sk -X POST "${API}/api/bert/predict" \
    -H 'Content-Type: application/json' \
    -d "{\"task\":\"rag_memory\",\"text\":\"Helical memory anchor\",\"tenantId\":\"${TENANT}\"}" | jq .
}

mayhem_batch() {
  local tasks='['
  local i text
  for i in $(seq 1 "$BATCH"); do
    text="Swarm vector ${i} for shared memory RAG pipeline"
    tasks+="{\"task\":\"agent_coordination\",\"text\":\"${text}\",\"tenantId\":\"${TENANT}\"}"
    [[ "$i" -lt "$BATCH" ]] && tasks+=','
  done
  tasks+=']'
  curl -sk -X POST "${API}/api/bert/batch" \
    -H 'Content-Type: application/json' \
    -d "{\"tenantId\":\"${TENANT}\",\"tasks\":${tasks}}" | jq .
}

log "status"
curl -sk "${API}/api/bert/status" | jq .
log "light probe"
light_probe
if [[ "${BERT_SWARM_MAYHEM:-0}" == "1" ]]; then
  log "mayhem batch (${BATCH})"
  mayhem_batch
fi
