#!/usr/bin/env bash
# =============================================================================
# configure-vmss-autoscale.sh — YieldSwarm VMSS autoscale (reactive + predictive)
#
# Configures:
#   • Metric rules — scale out at high CPU, scale in at low CPU (wide gap)
#   • Predictive autoscale — forecast-only or enabled (Percentage CPU)
#   • Scheduled business-hours profile (optional)
#   • Scale-in policy — OldestVM (protect long-running agent sessions)
#   • GPU VMSS autoscale (optional, separate setting)
#
# Usage:
#   ./scripts/azure/configure-vmss-autoscale.sh --env deploy/azure-mainnet.env
#   ./scripts/azure/configure-vmss-autoscale.sh --dry-run
#   ./scripts/azure/configure-vmss-autoscale.sh --replace   # delete + recreate rules
#   ./scripts/azure/configure-vmss-autoscale.sh --gpu-only
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${REPO_ROOT}/deploy/azure-mainnet.env"

DRY_RUN=0
REPLACE=0
GPU_ONLY=0
CPU_ONLY=0
SKIP_SCHEDULE=0

log()  { printf '[autoscale] %s\n' "$*"; }
warn() { printf '[autoscale][warn] %s\n' "$*" >&2; }
die()  { printf '[autoscale][fail] %s\n' "$*" >&2; exit 1; }
step() { printf '\n==> %s\n' "$*"; }

run() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

load_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    if [[ -f "${REPO_ROOT}/deploy/azure-mainnet.env.example" ]]; then
      warn "using example env — copy to deploy/azure-mainnet.env for live deploy"
      ENV_FILE="${REPO_ROOT}/deploy/azure-mainnet.env.example"
    else
      die "missing env file: ${ENV_FILE}"
    fi
  fi
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a

  # Defaults (CPU VMSS)
  AZURE_RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-YieldSwarm}"
  AZURE_VMSS_NAME="${AZURE_VMSS_NAME:-vmss_3cf043e}"
  AZURE_AUTOSCALE_NAME="${AZURE_AUTOSCALE_NAME:-autoscale-${AZURE_VMSS_NAME}}"
  AZURE_AUTOSCALE_MIN="${AZURE_AUTOSCALE_MIN:-2}"
  AZURE_AUTOSCALE_MAX="${AZURE_AUTOSCALE_MAX:-10}"
  AZURE_AUTOSCALE_DEFAULT="${AZURE_AUTOSCALE_DEFAULT:-${AZURE_VMSS_CAPACITY:-2}}"
  AZURE_AUTOSCALE_SCALE_OUT_CPU="${AZURE_AUTOSCALE_SCALE_OUT_CPU:-75}"
  AZURE_AUTOSCALE_SCALE_IN_CPU="${AZURE_AUTOSCALE_SCALE_IN_CPU:-30}"
  AZURE_AUTOSCALE_CPU_DURATION="${AZURE_AUTOSCALE_CPU_DURATION:-10m}"
  AZURE_AUTOSCALE_COOLDOWN_OUT="${AZURE_AUTOSCALE_COOLDOWN_OUT:-5}"
  AZURE_AUTOSCALE_COOLDOWN_IN="${AZURE_AUTOSCALE_COOLDOWN_IN:-10}"
  AZURE_AUTOSCALE_SCALE_OUT_COUNT="${AZURE_AUTOSCALE_SCALE_OUT_COUNT:-1}"
  AZURE_AUTOSCALE_SCALE_IN_COUNT="${AZURE_AUTOSCALE_SCALE_IN_COUNT:-1}"
  AZURE_VMSS_SCALE_IN_POLICY="${AZURE_VMSS_SCALE_IN_POLICY:-OldestVM}"
  AZURE_AUTOSCALE_PREDICTIVE_MODE="${AZURE_AUTOSCALE_PREDICTIVE_MODE:-ForecastOnly}"
  AZURE_AUTOSCALE_LOOKAHEAD="${AZURE_AUTOSCALE_LOOKAHEAD:-PT15M}"

  # Scheduled profile
  AZURE_AUTOSCALE_SCHEDULE_ENABLED="${AZURE_AUTOSCALE_SCHEDULE_ENABLED:-1}"
  AZURE_AUTOSCALE_SCHEDULE_NAME="${AZURE_AUTOSCALE_SCHEDULE_NAME:-business-hours}"
  AZURE_AUTOSCALE_SCHEDULE_START="${AZURE_AUTOSCALE_SCHEDULE_START:-08:00}"
  AZURE_AUTOSCALE_SCHEDULE_END="${AZURE_AUTOSCALE_SCHEDULE_END:-18:00}"
  AZURE_AUTOSCALE_SCHEDULE_DAYS="${AZURE_AUTOSCALE_SCHEDULE_DAYS:-mon tue wed thu fri}"
  AZURE_AUTOSCALE_SCHEDULE_TIMEZONE="${AZURE_AUTOSCALE_SCHEDULE_TIMEZONE:-Central Standard Time}"
  AZURE_AUTOSCALE_SCHEDULE_COUNT="${AZURE_AUTOSCALE_SCHEDULE_COUNT:-4}"
  AZURE_AUTOSCALE_SCHEDULE_MIN="${AZURE_AUTOSCALE_SCHEDULE_MIN:-2}"
  AZURE_AUTOSCALE_SCHEDULE_MAX="${AZURE_AUTOSCALE_SCHEDULE_MAX:-8}"

  # GPU VMSS autoscale
  AZURE_GPU_VMSS_NAME="${AZURE_GPU_VMSS_NAME:-vmss_gpu_yieldswarm}"
  AZURE_GPU_AUTOSCALE_ENABLED="${AZURE_GPU_AUTOSCALE_ENABLED:-1}"
  AZURE_GPU_AUTOSCALE_NAME="${AZURE_GPU_AUTOSCALE_NAME:-autoscale-${AZURE_GPU_VMSS_NAME}}"
  AZURE_GPU_AUTOSCALE_MIN="${AZURE_GPU_AUTOSCALE_MIN:-1}"
  AZURE_GPU_AUTOSCALE_MAX="${AZURE_GPU_AUTOSCALE_MAX:-6}"
  AZURE_GPU_AUTOSCALE_DEFAULT="${AZURE_GPU_AUTOSCALE_DEFAULT:-${AZURE_GPU_VMSS_CAPACITY:-2}}"
  AZURE_GPU_AUTOSCALE_SCALE_OUT_CPU="${AZURE_GPU_AUTOSCALE_SCALE_OUT_CPU:-70}"
  AZURE_GPU_AUTOSCALE_SCALE_IN_CPU="${AZURE_GPU_AUTOSCALE_SCALE_IN_CPU:-25}"
}

require_tools() {
  if [[ "${DRY_RUN}" == "1" ]]; then
    command -v az >/dev/null 2>&1 || warn "az CLI not installed — dry-run only"
    return 0
  fi
  command -v az >/dev/null 2>&1 || die "install Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli"
  az account show >/dev/null 2>&1 || die "run: az login"
  if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
    az account set --subscription "${AZURE_SUBSCRIPTION_ID}"
  fi
}

autoscale_exists() {
  local name="$1"
  if [[ "${DRY_RUN}" == "1" ]]; then
    return 1
  fi
  az monitor autoscale show \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${name}" >/dev/null 2>&1
}

delete_autoscale_if_replace() {
  local name="$1"
  if [[ "${REPLACE}" != "1" ]]; then
    return 0
  fi
  if autoscale_exists "${name}"; then
    step "Deleting existing autoscale setting ${name} (--replace)"
    run az monitor autoscale delete \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${name}" \
      --yes
  fi
}

create_autoscale_setting() {
  local name="$1" vmss="$2" min="$3" max="$4" count="$5"

  if autoscale_exists "${name}"; then
    if [[ "${REPLACE}" == "1" ]]; then
      return 0
    fi
    log "autoscale ${name} exists — updating bounds (use --replace to recreate rules)"
    run az monitor autoscale update \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${name}" \
      --min-count "${min}" \
      --max-count "${max}" \
      --count "${count}" \
      --enabled true \
      --output none
    return 1
  fi

  step "Creating autoscale setting ${name} for VMSS ${vmss}"
  run az monitor autoscale create \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --resource "${vmss}" \
    --resource-type Microsoft.Compute/virtualMachineScaleSets \
    --name "${name}" \
    --min-count "${min}" \
    --max-count "${max}" \
    --count "${count}" \
    --output none
  return 0
}

add_metric_rules() {
  local name="$1" scale_out_cpu="$2" scale_in_cpu="$3"

  step "Metric rules — scale out >${scale_out_cpu}% / scale in <${scale_in_cpu}% (${AZURE_AUTOSCALE_CPU_DURATION})"

  run az monitor autoscale rule create \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --autoscale-name "${name}" \
    --condition "Percentage CPU > ${scale_out_cpu} avg ${AZURE_AUTOSCALE_CPU_DURATION}" \
    --scale out "${AZURE_AUTOSCALE_SCALE_OUT_COUNT}" \
    --cooldown "${AZURE_AUTOSCALE_COOLDOWN_OUT}"

  run az monitor autoscale rule create \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --autoscale-name "${name}" \
    --condition "Percentage CPU < ${scale_in_cpu} avg ${AZURE_AUTOSCALE_CPU_DURATION}" \
    --scale in "${AZURE_AUTOSCALE_SCALE_IN_COUNT}" \
    --cooldown "${AZURE_AUTOSCALE_COOLDOWN_IN}"
}

enable_predictive() {
  local name="$1"
  local mode="${AZURE_AUTOSCALE_PREDICTIVE_MODE}"

  if [[ "${mode}" == "Disabled" ]]; then
    log "predictive autoscale disabled for ${name}"
    return 0
  fi

  step "Predictive autoscale — ${mode} (lookahead ${AZURE_AUTOSCALE_LOOKAHEAD})"
  run az monitor autoscale update \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${name}" \
    --scale-mode "${mode}" \
    --scale-look-ahead-time "${AZURE_AUTOSCALE_LOOKAHEAD}" \
    --output none

  if [[ "${mode}" == "ForecastOnly" ]]; then
    log "forecast-only mode — validate predictions in portal before enabling"
  fi
}

add_business_hours_profile() {
  local name="$1"

  if [[ "${AZURE_AUTOSCALE_SCHEDULE_ENABLED}" != "1" ]]; then
    log "scheduled profile disabled"
    return 0
  fi
  if [[ "${SKIP_SCHEDULE}" == "1" ]]; then
    warn "skipping scheduled profile (--skip-schedule)"
    return 0
  fi

  step "Scheduled profile ${AZURE_AUTOSCALE_SCHEDULE_NAME} (${AZURE_AUTOSCALE_SCHEDULE_START}-${AZURE_AUTOSCALE_SCHEDULE_END})"

  # shellcheck disable=SC2086
  run az monitor autoscale profile create \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --autoscale-name "${name}" \
    --name "${AZURE_AUTOSCALE_SCHEDULE_NAME}" \
    --copy-rules default \
    --min-count "${AZURE_AUTOSCALE_SCHEDULE_MIN}" \
    --max-count "${AZURE_AUTOSCALE_SCHEDULE_MAX}" \
    --count "${AZURE_AUTOSCALE_SCHEDULE_COUNT}" \
    --recurrence week ${AZURE_AUTOSCALE_SCHEDULE_DAYS} \
    --start "${AZURE_AUTOSCALE_SCHEDULE_START}" \
    --end "${AZURE_AUTOSCALE_SCHEDULE_END}" \
    --timezone "${AZURE_AUTOSCALE_SCHEDULE_TIMEZONE}"
}

set_scale_in_policy() {
  local vmss="$1" policy="$2"

  step "Scale-in policy ${policy} on ${vmss}"
  run az vmss update \
    --resource-group "${AZURE_RESOURCE_GROUP}" \
    --name "${vmss}" \
    --scale-in-policy "${policy}" \
    --output none
}

configure_vmss_autoscale() {
  local name="$1" vmss="$2" min="$3" max="$4" count="$5" out_cpu="$6" in_cpu="$7"

  delete_autoscale_if_replace "${name}"

  local created=0
  if create_autoscale_setting "${name}" "${vmss}" "${min}" "${max}" "${count}"; then
    created=1
  fi

  if [[ "${created}" == "1" || "${REPLACE}" == "1" ]]; then
    add_metric_rules "${name}" "${out_cpu}" "${in_cpu}"
    if [[ "${name}" == "${AZURE_AUTOSCALE_NAME}" ]]; then
      add_business_hours_profile "${name}"
    fi
  fi

  enable_predictive "${name}"
  set_scale_in_policy "${vmss}" "${AZURE_VMSS_SCALE_IN_POLICY}"
}

configure_cpu_vmss() {
  step "CPU VMSS autoscale — ${AZURE_VMSS_NAME}"
  configure_vmss_autoscale \
    "${AZURE_AUTOSCALE_NAME}" \
    "${AZURE_VMSS_NAME}" \
    "${AZURE_AUTOSCALE_MIN}" \
    "${AZURE_AUTOSCALE_MAX}" \
    "${AZURE_AUTOSCALE_DEFAULT}" \
    "${AZURE_AUTOSCALE_SCALE_OUT_CPU}" \
    "${AZURE_AUTOSCALE_SCALE_IN_CPU}"
}

configure_gpu_vmss() {
  if [[ "${AZURE_GPU_AUTOSCALE_ENABLED}" != "1" ]]; then
    log "GPU autoscale disabled (AZURE_GPU_AUTOSCALE_ENABLED=0)"
    return 0
  fi

  if [[ "${DRY_RUN}" == "0" ]]; then
    if ! az vmss show \
      --resource-group "${AZURE_RESOURCE_GROUP}" \
      --name "${AZURE_GPU_VMSS_NAME}" >/dev/null 2>&1; then
      warn "GPU VMSS ${AZURE_GPU_VMSS_NAME} not found — skipping GPU autoscale"
      return 0
    fi
  else
    log "[dry-run] would check GPU VMSS ${AZURE_GPU_VMSS_NAME}"
  fi

  step "GPU VMSS autoscale — ${AZURE_GPU_VMSS_NAME}"
  configure_vmss_autoscale \
    "${AZURE_GPU_AUTOSCALE_NAME}" \
    "${AZURE_GPU_VMSS_NAME}" \
    "${AZURE_GPU_AUTOSCALE_MIN}" \
    "${AZURE_GPU_AUTOSCALE_MAX}" \
    "${AZURE_GPU_AUTOSCALE_DEFAULT}" \
    "${AZURE_GPU_AUTOSCALE_SCALE_OUT_CPU}" \
    "${AZURE_GPU_AUTOSCALE_SCALE_IN_CPU}"
}

print_summary() {
  step "Autoscale summary"
  cat <<EOF
  CPU VMSS:           ${AZURE_VMSS_NAME}
  CPU autoscale:      ${AZURE_AUTOSCALE_NAME} (${AZURE_AUTOSCALE_MIN}-${AZURE_AUTOSCALE_MAX}, default ${AZURE_AUTOSCALE_DEFAULT})
  CPU thresholds:     out >${AZURE_AUTOSCALE_SCALE_OUT_CPU}% / in <${AZURE_AUTOSCALE_SCALE_IN_CPU}% over ${AZURE_AUTOSCALE_CPU_DURATION}
  Predictive mode:    ${AZURE_AUTOSCALE_PREDICTIVE_MODE} (lookahead ${AZURE_AUTOSCALE_LOOKAHEAD})
  Scale-in policy:    ${AZURE_VMSS_SCALE_IN_POLICY}
  Schedule profile:   ${AZURE_AUTOSCALE_SCHEDULE_NAME} (${AZURE_AUTOSCALE_SCHEDULE_ENABLED:+enabled}${AZURE_AUTOSCALE_SCHEDULE_ENABLED:-disabled})

  GPU VMSS:           ${AZURE_GPU_VMSS_NAME} (autoscale ${AZURE_GPU_AUTOSCALE_ENABLED})
  GPU autoscale:      ${AZURE_GPU_AUTOSCALE_NAME} (${AZURE_GPU_AUTOSCALE_MIN}-${AZURE_GPU_AUTOSCALE_MAX})

  Instance protection (long-running agents):
    az vmss vm update -g ${AZURE_RESOURCE_GROUP} -n ${AZURE_VMSS_NAME} \\
      --instance-id <id> --protect-from-scale-in true

  View predictive forecast:
    az monitor autoscale show-predictive-metric -g ${AZURE_RESOURCE_GROUP} -n ${AZURE_AUTOSCALE_NAME}

  Docs: docs/AZURE_VMSS_AUTOSCALE.md
EOF
}

usage() {
  sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --replace) REPLACE=1; shift ;;
    --gpu-only) GPU_ONLY=1; shift ;;
    --cpu-only) CPU_ONLY=1; shift ;;
    --skip-schedule) SKIP_SCHEDULE=1; shift ;;
    -h|--help) usage ;;
    *) die "unknown arg: $1" ;;
  esac
done

main() {
  load_env
  require_tools

  if [[ "${GPU_ONLY}" == "0" ]]; then
    configure_cpu_vmss
  fi
  if [[ "${CPU_ONLY}" == "0" ]]; then
    configure_gpu_vmss
  fi

  print_summary
  log "configure-vmss-autoscale complete"
}

main "$@"
