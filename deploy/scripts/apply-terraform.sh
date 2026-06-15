#!/usr/bin/env bash
# =============================================================================
# STEP 3 — Apply Terraform multi-cloud fallback.
#
#   deploy/scripts/apply-terraform.sh [plan|apply|destroy]   (default: apply)
#
# Generates deploy/terraform/auto.tfvars.json from deploy/config.env and the
# live Akash lease (.run/akash-lease.env), then runs terraform init + the
# requested action. Akash stays primary; this only spins up a managed-cloud
# fallback if a fallback is enabled AND the Akash worker is unhealthy.
# =============================================================================
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config

ACTION="${1:-apply}"
TFD="${REPO_ROOT}/${TF_DIR}"
TFVARS="${TFD}/auto.tfvars.json"

primary_health_url() {
  # Prefer an explicit value; otherwise derive from the Akash lease URIs.
  local lease="${REPO_ROOT}/${RUN_DIR}/akash-lease.env"
  if [[ -n "${WORKER_URLS}" ]]; then
    echo "${WORKER_URLS%%,*}/healthz"; return
  fi
  if [[ -f "$lease" ]]; then
    # shellcheck disable=SC1090
    source "$lease"
    if [[ -n "${AKASH_WORKER_URLS:-}" ]]; then
      echo "${AKASH_WORKER_URLS%%,*}/healthz"; return
    fi
  fi
  echo ""
}

gen_tfvars() {
  step "Generating ${TFVARS}"
  local health; health="$(primary_health_url)"
  python3 - "$TFVARS" <<PY
import json, os, sys
data = {
    "ghcr_owner":        os.environ.get("GHCR_OWNER", ""),
    "image_prefix":      os.environ.get("IMAGE_PREFIX", "yieldswarm"),
    "image_tag":         os.environ.get("IMAGE_TAG", "latest"),
    "primary_health_url":"${health}",
    "enable_fly":        os.environ.get("TF_ENABLE_FLY", "false") == "true",
    "enable_render":     os.environ.get("TF_ENABLE_RENDER", "false") == "true",
    "enable_hetzner":    os.environ.get("TF_ENABLE_HETZNER", "false") == "true",
    "fly_api_token":     os.environ.get("FLY_API_TOKEN", ""),
    "render_api_key":    os.environ.get("RENDER_API_KEY", ""),
    "hcloud_token":      os.environ.get("HCLOUD_TOKEN", ""),
}
json.dump(data, open(sys.argv[1], "w"), indent=2)
print("wrote", sys.argv[1])
PY
  ok "tfvars generated (primary_health_url=${health:-<none>})"
}

main() {
  step "STEP 3 — Terraform multi-cloud fallback (${ACTION})"
  require terraform python3
  [[ -d "$TFD" ]] || die "terraform dir not found: ${TFD}"
  gen_tfvars

  ( cd "$TFD" && terraform init -input=false )
  case "$ACTION" in
    plan)    ( cd "$TFD" && terraform plan    -input=false -var-file="$TFVARS" ) ;;
    apply)   ( cd "$TFD" && terraform apply   -input=false -auto-approve -var-file="$TFVARS" ) ;;
    destroy) ( cd "$TFD" && terraform destroy -input=false -auto-approve -var-file="$TFVARS" ) ;;
    *)       die "unknown action: ${ACTION} (use plan|apply|destroy)" ;;
  esac
  ok "STEP 3 complete"
}

main "$@"
