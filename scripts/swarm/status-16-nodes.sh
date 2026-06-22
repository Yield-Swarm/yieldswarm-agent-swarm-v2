#!/usr/bin/env bash
# Print swarm node status from local state files (all 16 nodes).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${REPO_ROOT}/.run/swarm-nodes"

echo "YieldSwarm 16-node swarm status"
echo "================================"

online=0
for id in $(seq 1 16); do
  state="${RUN_DIR}/node-${id}-state.json"
  if [[ -f "${state}" ]]; then
    online=$((online + 1))
    python3 -c "
import json, sys
s = json.load(open(sys.argv[1]))
p = s.get('probes', {})
litellm = p.get('litellm', {})
vllm = p.get('vllm', {})
print(f\"  node {s['nodeId']:2d}  {s['tier']:6s}  {s['model']:22s}  litellm={'ok' if litellm.get('ok') else '—'}  vllm={'ok' if vllm.get('ok') else '—'}  @ {s.get('updatedAt','')}\")
" "${state}"
  else
    echo "  node ${id}   offline"
  fi
done

echo "--------------------------------"
echo "online: ${online}/16"
if [[ "${online}" -lt 16 ]]; then
  echo "tip: export SWARM_NODE_ID=N && npm run run-all-onchain on each Termux instance"
  exit 1
fi
