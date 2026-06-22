#!/usr/bin/env bash
# =============================================================================
# export-cloud-specs.sh — Azure, GCP, RunPod VM/GPU inventory + 30-day usage
#
# For Cherry Servers free-credits justification (Justas | CherryServers).
#
# Usage:
#   ./scripts/cherry-servers/export-cloud-specs.sh
#   ./scripts/cherry-servers/export-cloud-specs.sh --json
#   VAULT_TOKEN=... ./scripts/cherry-servers/export-cloud-specs.sh --load-vault
#
# Prerequisites:
#   az login (or AZURE_* service principal via Vault)
#   gcloud auth application-default login (or GOOGLE_APPLICATION_CREDENTIALS)
#   RUNPOD_API_KEY (Vault: yieldswarm/cloud/runpod)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RUN_DIR="${RUN_DIR:-${REPO_ROOT}/.run}"
OUT_JSON="${RUN_DIR}/cherry-servers-cloud-specs.json"
OUT_MD="${RUN_DIR}/cherry-servers-cloud-specs.md"
LOAD_VAULT=0
JSON_ONLY=0
DAYS=30

for arg in "$@"; do
  case "$arg" in
    --load-vault) LOAD_VAULT=1 ;;
    --json) JSON_ONLY=1 ;;
    --days=*) DAYS="${arg#*=}" ;;
  esac
done

mkdir -p "${RUN_DIR}"
START_ISO="$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-"${DAYS}"d +%Y-%m-%dT%H:%M:%SZ)"
END_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
REPORT_DATE="$(date -u +%Y-%m-%d)"

log() { printf '[cherry-specs] %s\n' "$*" >&2; }

# shellcheck disable=SC1091
[[ -f "${REPO_ROOT}/.env" ]] && set -a && source "${REPO_ROOT}/.env" && set +a

load_vault_cloud() {
  command -v vault >/dev/null 2>&1 || { log "vault CLI not found — skip --load-vault"; return 0; }
  [[ -n "${VAULT_TOKEN:-}" ]] || { log "VAULT_TOKEN unset — skip Vault load"; return 0; }
  export VAULT_ADDR="${VAULT_ADDR:-https://vault.yieldswarm.io:8200}"

  if vault kv get -format=json yieldswarm/cloud/azure >/dev/null 2>&1; then
    eval "$(vault kv get -format=json yieldswarm/cloud/azure | jq -r '
      .data.data | to_entries[] | "export AZURE_\(.key | ascii_upcase)=\(.value | @sh)"
    ')"
    export AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_CLIENT_ID AZURE_CLIENT_SECRET
    az login --service-principal \
      -u "${AZURE_CLIENT_ID}" \
      -p "${AZURE_CLIENT_SECRET}" \
      --tenant "${AZURE_TENANT_ID}" >/dev/null 2>&1 || true
  fi

  if vault kv get -format=json yieldswarm/cloud/runpod >/dev/null 2>&1; then
    export RUNPOD_API_KEY
    RUNPOD_API_KEY="$(vault kv get -field=api_key yieldswarm/cloud/runpod 2>/dev/null || true)"
  fi

  if vault kv get -format=json yieldswarm/cloud/gcp >/dev/null 2>&1; then
    local creds_file="${RUN_DIR}/gcp-sa.json"
    vault kv get -format=json yieldswarm/cloud/gcp | jq -r '.data.data.credentials_json // .data.data.service_account_json // empty' > "${creds_file}" 2>/dev/null || true
    if [[ -s "${creds_file}" ]]; then
      export GOOGLE_APPLICATION_CREDENTIALS="${creds_file}"
      export GCP_PROJECT_ID
      GCP_PROJECT_ID="$(jq -r .project_id "${creds_file}")"
      gcloud auth activate-service-account --key-file="${creds_file}" >/dev/null 2>&1 || true
    fi
  fi
}

[[ "${LOAD_VAULT}" -eq 1 ]] && load_vault_cloud

AZURE_JSON='{"status":"skipped","reason":"az CLI or subscription missing","vms":[],"container_groups":[],"metrics":[]}'
GCP_JSON='{"status":"skipped","reason":"gcloud or project missing","instances":[],"metrics":[]}'
RUNPOD_JSON='{"status":"skipped","reason":"RUNPOD_API_KEY missing","pods":[],"gpu_types":[],"metrics_note":"RunPod API exposes live GPU util; 30d averages require console billing export"}'

# --- Azure -------------------------------------------------------------------
if command -v az >/dev/null 2>&1; then
  if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]] || az account show >/dev/null 2>&1; then
  log "Collecting Azure inventory..."
  SUB="${AZURE_SUBSCRIPTION_ID:-$(az account show --query id -o tsv 2>/dev/null || true)}"
  RG_FILTER="${AZURE_RESOURCE_GROUP:-}"

  VM_LIST="$(az vm list ${RG_FILTER:+--resource-group "$RG_FILTER"} -o json 2>/dev/null || echo '[]')"
  ACI_LIST="$(az container list ${RG_FILTER:+--resource-group "$RG_FILTER"} -o json 2>/dev/null || echo '[]')"

  VM_ENRICHED='[]'
  while IFS= read -r vm_name; do
    [[ -z "$vm_name" ]] && continue
    rg="$(echo "${VM_LIST}" | jq -r --arg n "$vm_name" '.[] | select(.name==$n) | .resourceGroup' | head -1)"
    [[ -z "$rg" || "$rg" == "null" ]] && continue
    detail="$(az vm show -g "$rg" -n "$vm_name" -o json 2>/dev/null || echo '{}')"
    view="$(az vm get-instance-view -g "$rg" -n "$vm_name" -o json 2>/dev/null || echo '{}')"
    size="$(echo "$detail" | jq -r '.hardwareProfile.vmSize // "unknown"')"
    size_info="$(az vm list-sizes --location "$(echo "$detail" | jq -r '.location')" --query "[?name=='${size}']" -o json 2>/dev/null | jq '.[0] // {}')"
    vm_id="$(echo "$detail" | jq -r '.id')"
    cpu_metric='null'
    mem_metric='null'
    if [[ -n "$vm_id" && "$vm_id" != "null" ]]; then
      cpu_metric="$(az monitor metrics list --resource "$vm_id" \
        --metric "Percentage CPU" --start-time "$START_ISO" --end-time "$END_ISO" \
        --interval PT1H --aggregation Average Maximum -o json 2>/dev/null \
        | jq '[.value[0].timeseries[0].data[]? | select(.average!=null) | .average] | if length>0 then {avg: (add/length), max: max, samples: length} else null end' || echo 'null')"
      mem_metric="$(az monitor metrics list --resource "$vm_id" \
        --metric "Available Memory Bytes" --start-time "$START_ISO" --end-time "$END_ISO" \
        --interval PT1H --aggregation Average -o json 2>/dev/null \
        | jq '[.value[0].timeseries[0].data[]? | select(.average!=null) | .average] | if length>0 then {avg_bytes: (add/length), samples: length} else null end' || echo 'null')"
    fi
    disks="$(az vm show -g "$rg" -n "$vm_name" --query storageProfile -o json 2>/dev/null || echo '{}')"
    VM_ENRICHED="$(jq -nc --argjson arr "$VM_ENRICHED" --argjson d "$detail" --argjson v "$view" \
      --argjson sz "$size_info" --argjson cpu "$cpu_metric" --argjson mem "$mem_metric" --argjson disks "$disks" \
      '$arr + [{
        name: $d.name,
        resource_group: ($d.resourceGroup // ""),
        location: ($d.location // ""),
        vm_size: ($d.hardwareProfile.vmSize // ""),
        cpu_cores: ($sz.numberOfCores // null),
        ram_mb: ($sz.memoryInMb // null),
        os_disk: ($disks.osDisk // {}),
        data_disks: ($disks.dataDisks // []),
        power_state: ($v.instanceView.statuses[]? | select(.code | startswith("PowerState")) | .displayStatus // "unknown"),
        gpu: (if ($d.hardwareProfile.vmSize // "" | test("NC|ND|NV|NG"; "i")) then "likely_gpu_sku" else null end),
        metrics_30d: {cpu_percent: $cpu, available_memory_bytes: $mem}
      }]')"
  done < <(echo "${VM_LIST}" | jq -r '.[].name')

  ACI_ENRICHED="$(echo "${ACI_LIST}" | jq '[.[] | {
    name: .name,
    resource_group: (.resourceGroup // ""),
    location: (.location // ""),
    cpu_cores: (.containers[0].resources.requests.cpu // null),
    memory_gb: (.containers[0].resources.requests.memoryInGb // null),
    image: (.containers[0].image // ""),
    state: (.instanceView.state // "unknown")
  }]')"

  AZURE_JSON="$(jq -nc \
    --arg sub "$SUB" \
    --argjson vms "$VM_ENRICHED" \
    --argjson aci "$ACI_ENRICHED" \
    --arg start "$START_ISO" --arg end "$END_ISO" \
    '{status:"ok", subscription_id:$sub, window:{start:$start,end:$end}, vms:$vms, container_groups:$aci}')"
  else
    log "Azure: skipped (az login or AZURE_SUBSCRIPTION_ID required)"
  fi
else
  log "Azure: skipped (az CLI not installed)"
fi

# --- GCP ---------------------------------------------------------------------
if command -v gcloud >/dev/null 2>&1; then
  PROJECT="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
  if [[ -n "$PROJECT" && "$PROJECT" != "(unset)" ]]; then
    log "Collecting GCP inventory (project=${PROJECT})..."
    INSTANCES="$(gcloud compute instances list --project="$PROJECT" --format=json 2>/dev/null || echo '[]')"
    GCP_ENRICHED='[]'
    while IFS=$'\t' read -r name zone; do
      [[ -z "$name" ]] && continue
      detail="$(gcloud compute instances describe "$name" --zone="$zone" --project="$PROJECT" --format=json 2>/dev/null || echo '{}')"
      machine_type="$(echo "$detail" | jq -r '.machineType | split("/") | last')"
      mt_detail="$(gcloud compute machine-types describe "$machine_type" --zone="$zone" --project="$PROJECT" --format=json 2>/dev/null || echo '{}')"
      disks="$(echo "$detail" | jq '[.disks[]? | {device: .deviceName, mode: .mode, boot: .boot, type: .type, sizeGb: .diskSizeGb}]')"
      gpus="$(echo "$detail" | jq '[.guestAccelerators[]? | {type: .acceleratorType, count: .acceleratorCount}]')"
      instance_id="$(echo "$detail" | jq -r '.id')"
      cpu_util='null'
      if [[ -n "$instance_id" && "$instance_id" != "null" ]]; then
        cpu_util="$(gcloud monitoring time-series list \
          --project="$PROJECT" \
          --filter="metric.type=\"compute.googleapis.com/instance/cpu/utilization\" AND resource.labels.instance_id=\"${instance_id}\"" \
          --start-time="-${DAYS}d" --end-time=now \
          --format=json 2>/dev/null \
          | jq '[.[].points[]?.value.doubleValue // .[].points[]?.value.int64Value // empty] | if length>0 then {avg: (add/length), max: max, samples: length} else null end' || echo 'null')"
      fi
      GCP_ENRICHED="$(jq -nc --argjson arr "$GCP_ENRICHED" --argjson d "$detail" --argjson mt "$mt_detail" \
        --argjson disks "$disks" --argjson gpus "$gpus" --argjson cpu "$cpu_util" --arg name "$name" --arg zone "$zone" \
        '$arr + [{
          name: $name,
          zone: $zone,
          machine_type: ($d.machineType | split("/") | last),
          cpu_cores: ($mt.guestCpus // null),
          ram_mb: ($mt.memoryMb // null),
          status: ($d.status // "UNKNOWN"),
          disks: $disks,
          gpus: $gpus,
          metrics_30d: {cpu_utilization_ratio: $cpu}
        }]')"
    done < <(echo "${INSTANCES}" | jq -r '.[] | [.name, .zone] | @tsv')

    GCP_JSON="$(jq -nc --arg project "$PROJECT" --argjson instances "$GCP_ENRICHED" \
      --arg start "$START_ISO" --arg end "$END_ISO" \
      '{status:"ok", project_id:$project, window:{start:$start,end:$end}, instances:$instances}')"
  else
    GCP_JSON='{"status":"skipped","reason":"GCP project not set — export GCP_PROJECT_ID or gcloud config set project"}'
  fi
else
  log "GCP: skipped (install gcloud)"
fi

# --- RunPod ------------------------------------------------------------------
RUNPOD_ENDPOINT="${RUNPOD_ENDPOINT:-https://api.runpod.io/graphql}"
if [[ -n "${RUNPOD_API_KEY:-}" ]]; then
  log "Collecting RunPod inventory..."
  RP_QUERY='query CherrySpecs {
    gpuTypes { id displayName memoryInGb secureCloud communityCloud lowestPrice { minimumBidPrice uninterruptablePrice } }
    myself {
      pods {
        id name desiredStatus costPerHr
        machine { gpuDisplayName gpuCount }
        runtime {
          uptimeInSeconds
          gpus { id gpuUtilPercent memoryUtilPercent }
        }
      }
    }
  }'
  RP_RESP="$(curl -sfS "${RUNPOD_ENDPOINT}" \
    -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$(jq -nc --arg q "$RP_QUERY" '{query: $q}')" 2>/dev/null || echo '{}')"

  RUNPOD_JSON="$(echo "${RP_RESP}" | jq --arg start "$START_ISO" --arg end "$END_ISO" '{
    status: (if .data then "ok" else "error" end),
    window: {start: $start, end: $end},
    gpu_types: (.data.gpuTypes // []),
    pods: (.data.myself.pods // [] | map({
      id, name, desiredStatus, costPerHr,
      gpu_model: (.machine.gpuDisplayName // "unknown"),
      gpu_count: (.machine.gpuCount // 0),
      uptime_seconds: (.runtime.uptimeInSeconds // 0),
      live_gpu_util_percent: ([.runtime.gpus[]?.gpuUtilPercent // empty] | if length>0 then (add/length) else null end),
      live_gpu_mem_util_percent: ([.runtime.gpus[]?.memoryUtilPercent // empty] | if length>0 then (add/length) else null end)
    })),
    metrics_30d_note: "RunPod GraphQL exposes live utilization. For 30-day billing averages export RunPod console → Billing → Usage CSV and attach to Cherry Servers packet."
  }' 2>/dev/null || echo '{"status":"error","reason":"RunPod parse failed"}')"
else
  log "RunPod: skipped (export RUNPOD_API_KEY or use --load-vault)"
fi

# --- Assemble report ---------------------------------------------------------
FULL_JSON="$(jq -nc \
  --arg generated_at "$END_ISO" \
  --arg report_date "$REPORT_DATE" \
  --arg recipient "Justas | CherryServers" \
  --argjson azure "$AZURE_JSON" \
  --argjson gcp "$GCP_JSON" \
  --argjson runpod "$RUNPOD_JSON" \
  '{
    report_title: "YieldSwarm Multi-Cloud VM/GPU Specification Export",
    recipient: $recipient,
    generated_at_utc: $generated_at,
    report_date: $report_date,
    purpose: "Free cloud credits justification — CPU/RAM/storage/GPU inventory + 30d usage where available",
    azure: $azure,
    gcp: $gcp,
    runpod: $runpod
  }')"

echo "${FULL_JSON}" | jq '.' > "${OUT_JSON}"

if [[ "${JSON_ONLY}" -eq 1 ]]; then
  cat "${OUT_JSON}"
  exit 0
fi

# Markdown summary for Cherry Servers
{
  echo "# YieldSwarm Cloud Specs — Cherry Servers Credits Packet"
  echo ""
  echo "**Prepared for:** Justas | CherryServers  "
  echo "**Generated (UTC):** ${REPORT_DATE}  "
  echo "**Window:** last ${DAYS} days (${START_ISO} → ${END_ISO})"
  echo ""
  echo "---"
  echo ""
  echo "## Azure"
  echo '```json'
  echo "${FULL_JSON}" | jq '.azure'
  echo '```'
  echo ""
  echo "## Google Cloud"
  echo '```json'
  echo "${FULL_JSON}" | jq '.gcp'
  echo '```'
  echo ""
  echo "## RunPod"
  echo '```json'
  echo "${FULL_JSON}" | jq '.runpod'
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "Machine-readable export: \`${OUT_JSON}\`"
} > "${OUT_MD}"

log "Wrote ${OUT_JSON}"
log "Wrote ${OUT_MD}"
cat "${OUT_MD}"
