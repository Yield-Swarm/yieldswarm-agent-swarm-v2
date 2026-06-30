#!/usr/bin/env bash
# Deploy YieldSwarm PoUW mining fleet on Salad Cloud (~$100 credit budget).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/salad/lib/salad-api.sh
source "${REPO_ROOT}/scripts/salad/lib/salad-api.sh"

export SALAD_BUDGET_USD="${SALAD_BUDGET_USD:-100}"
export SALAD_REPLICAS="${SALAD_REPLICAS:-4}"
export SALAD_CONTAINER_NAME="${SALAD_CONTAINER_NAME:-yieldswarm-pouw-$(date +%Y%m%d%H%M)}"
export SALAD_CONTAINER_IMAGE="${SALAD_CONTAINER_IMAGE:-ubuntu:22.04}"

salad_validate_key
salad_require_org_project

log() { printf '[%s] [salad-deploy] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"; }

log "budget=\$${SALAD_BUDGET_USD} replicas=${SALAD_REPLICAS} org=${SALAD_ORGANIZATION} project=${SALAD_PROJECT}"

GPU_CLASSES_JSON="$(salad_list_gpu_classes)"
if echo "${GPU_CLASSES_JSON}" | grep -q '"title":"Not Found"'; then
  log "ERROR: cannot access org ${SALAD_ORGANIZATION} — copy slug from portal.salad.com URL"
  exit 1
fi

export GPU_CLASSES_JSON
PAYLOAD="$(python3 <<'PY'
import json, os, textwrap

raw = os.environ.get("GPU_CLASSES_JSON", "[]")
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    data = []
items = data if isinstance(data, list) else data.get("items", [])
preferred = []
for g in items:
    name = str(g.get("name", "")).lower()
    gid = g.get("id")
    if gid and any(x in name for x in ("4090", "3090", "4080")):
        preferred.append(gid)
if not preferred:
    preferred = [
        "9998fe42-04a5-4807-b3a5-849943f16c38",
        "ed563892-aacd-40f5-80b7-90c9be6c759b",
        "a5db5c50-cbcb-4596-ae80-6a0c8090d80f",
    ]

pool = os.environ.get("MINING_POOL_URL_PRL", "prl.2miners.com:1818")
wallet = os.environ.get("MINING_ROOT_PRL", "")
worker = os.environ.get("PRL_WORKER_NAME", "salad-gpu-fleet-1")
name = os.environ.get("SALAD_CONTAINER_NAME", "yieldswarm-pouw")
image = os.environ.get("SALAD_CONTAINER_IMAGE", "ubuntu:22.04")
replicas = int(os.environ.get("SALAD_REPLICAS", "4"))

startup = textwrap.dedent(f"""
    set -e
    apt-get update -qq && apt-get install -y -qq curl ca-certificates tar >/dev/null
    cd /tmp
    curl -fsSL -o srb.tgz https://github.com/doktor83/SRBMiner-Multi/releases/download/3.3.4/SRBMiner-Multi-linux-3.3.4.tar.gz || true
    tar -xzf srb.tgz 2>/dev/null || true
    BIN=$(find . -name 'SRBMiner-MULTI' | head -1)
    if [ -n "$BIN" ]; then chmod +x "$BIN"; fi
    WALLET="{wallet}"
    if [ -n "$WALLET" ] && [ "${{WALLET#prl1}}" = "$WALLET" ]; then
      echo "MINING_ROOT_PRL must be prl1… address"; sleep infinity
    fi
    if [ -n "$BIN" ] && [ -x "$BIN" ] && [ -n "$WALLET" ]; then
      exec "$BIN" --algorithm pearlhash --pool {pool} --wallet "$WALLET.{worker}" --password x --disable-cpu --gpu-threads 2 --pearl-cpu-cooldown 50
    fi
    sleep infinity
""").strip()

payload = {
    "name": name,
    "display_name": "YieldSwarm PoUW Pearl Fleet",
    "container": {
        "image": image,
        "command": ["bash", "-lc", startup],
        "resources": {
            "cpu": 4,
            "memory": 8192,
            "gpu_classes": preferred[:3],
        },
    },
    "autostart_policy": True,
    "restart_policy": "always",
    "replicas": replicas,
    "country_codes": ["us"],
}
print(json.dumps(payload))
PY
)"

log "creating container group ${SALAD_CONTAINER_NAME}"
CREATE_RESP="$(salad_create_container "${PAYLOAD}")"
echo "${CREATE_RESP}" | python3 -m json.tool 2>/dev/null || echo "${CREATE_RESP}"

if echo "${CREATE_RESP}" | grep -qE '"status":(400|403|404)'; then
  log "ERROR: create failed — verify credits in portal billing and org/project slugs"
  exit 1
fi

log "starting container group"
salad_start_container "${SALAD_CONTAINER_NAME}" | python3 -m json.tool 2>/dev/null || true

sleep 3
salad_get_container "${SALAD_CONTAINER_NAME}" | python3 -m json.tool 2>/dev/null || salad_get_container "${SALAD_CONTAINER_NAME}"

hourly="$(python3 -c "print(round(${SALAD_REPLICAS}*0.09,2))")"
log "deploy submitted — ~\$${hourly}/hr burn at 4× RTX4090 class (~\$${SALAD_BUDGET_USD} credit ≈ $(python3 -c "print(int(${SALAD_BUDGET_USD}/(${SALAD_REPLICAS}*0.09)))") hours)"
