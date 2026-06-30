#!/usr/bin/env bash
# Salad Cloud preflight — validate API key and org/project access.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/salad/lib/salad-api.sh
source "${REPO_ROOT}/scripts/salad/lib/salad-api.sh"

salad_validate_key
salad_require_org_project

echo "[salad] organization=${SALAD_ORGANIZATION} project=${SALAD_PROJECT}"

gpu_json="$(salad_list_gpu_classes)"
if echo "${gpu_json}" | grep -q '"status":404'; then
  echo "[salad] ERROR: organization not found or no access" >&2
  echo "${gpu_json}" >&2
  exit 1
fi

echo "[salad] GPU classes:"
echo "${gpu_json}" | python3 -c "
import json,sys
data=json.load(sys.stdin)
items=data if isinstance(data,list) else data.get('items',[])
for g in items[:12]:
    print(' -', g.get('name','?'), g.get('id',''))
" 2>/dev/null || echo "${gpu_json}" | head -c 500

containers="$(salad_api GET "/organizations/${SALAD_ORGANIZATION}/projects/${SALAD_PROJECT}/containers")"
echo "[salad] existing container groups:"
echo "${containers}" | python3 -c "
import json,sys
data=json.load(sys.stdin)
items=data if isinstance(data,list) else data.get('items',[])
for c in items[:10]:
    print(' -', c.get('name'), c.get('display_name',''))
print('total:', len(items))
" 2>/dev/null || echo "${containers}" | head -c 400

echo "[salad] preflight OK — ready to deploy"
