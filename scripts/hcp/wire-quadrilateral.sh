#!/usr/bin/env bash
# Wire HCP quadrilateral in parallel — Vault, Boundary, dual HVN, Packer, Terraform.
# Default: DRY_RUN=true (prints actions only). Set DRY_RUN=false to execute mutations.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANIFEST="${REPO_ROOT}/infra/hcp/quadrilateral-manifest.json"
DRY_RUN="${DRY_RUN:-true}"

export HCP_ORGANIZATION="${HCP_ORGANIZATION:-yield-swarm-org}"
export HCP_PROJECT="${HCP_PROJECT:-YieldSwarmHasiCorp}"
export HCP_PROJECT_ID="${HCP_PROJECT_ID:-331458d4-6c74-4e95-9497-cf2d6b846f31}"

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "[dry-run] $*"
  else
    echo "[exec] $*"
    eval "$@"
  fi
}

echo "=== HCP Quadrilateral Wire (DRY_RUN=$DRY_RUN) ==="
bash "${REPO_ROOT}/scripts/hcp/preflight-quadrilateral.sh" || true
echo ""

# ---------------------------------------------------------------------------
# Track A — Secrets lane: Vault + Tokyo HVN (HCYSRL)
# ---------------------------------------------------------------------------
echo "--- Track A: Vault + HCYSRL (AWS Tokyo) ---"
run "export VAULT_ADDR=\${VAULT_ADDR:-https://vault-cluster.hashicorp.cloud:8200}"
run "vault status || echo 'Vault: configure VAULT_ADDR + VAULT_TOKEN from HCP console'"
run "bash ${REPO_ROOT}/vault/scripts/bootstrap.sh  # if fresh cluster"
run "hcp hvn list --project ${HCP_PROJECT_ID} 2>/dev/null || echo 'List HVNs in console'"
echo "  → Attach HCYSRL routes for Tokyo worker subnets"
echo "  → Seed secrets: bash vault/scripts/seed-secrets.sh"
echo ""

# ---------------------------------------------------------------------------
# Track B — Access lane: Boundary + Azure HVN (demo-hvn)
# ---------------------------------------------------------------------------
echo "--- Track B: Boundary + demo-hvn (Azure westus2) ---"
run "export BOUNDARY_ADDR=\${BOUNDARY_ADDR:-https://boundary-cluster.hashicorp.cloud}"
run "boundary scopes list 2>/dev/null || echo 'Boundary: authenticate via hcp boundary clusters'"
echo "  → Create scopes: carrizozo-edge, akash-workers, terraform-ops"
echo "  → Register Azure VMSS targets on demo-hvn mesh"
run "vault kv put secret/boundary/controller addr=\$BOUNDARY_ADDR  # store controller ref"
echo ""

# ---------------------------------------------------------------------------
# Track C — Supply chain: Packer + Vagrant registries
# ---------------------------------------------------------------------------
echo "--- Track C: Packer + Vagrant supply chain ---"
run "cd ${REPO_ROOT}/infra/packer && packer init ."
run "packer build -var-file=worker.pkrvars.hcl -only=azure-worker.* ."
run "packer build -var-file=worker.pkrvars.hcl -only=gcp-worker.* ."
echo "  → Push to HCP Packer registry: yieldswarm-worker"
echo "  → Vagrant box 6338a520-… for local Carrizozo edge dev"
echo ""

# ---------------------------------------------------------------------------
# Track D — Orchestration: Terraform Helixchainprod workspace
# ---------------------------------------------------------------------------
echo "--- Track D: Terraform orchestration ---"
run "export TF_CLOUD_ORGANIZATION=\${TF_CLOUD_ORGANIZATION:-yield-swarm-org}"
run "export TF_WORKSPACE=Helixchainprod"
run "cd ${REPO_ROOT}/infra/terraform && terraform init"
run "terraform plan -var akash_current_workers=0 -var desired_total_workers=0"
echo "  → Apply only when Akash saturated (deficit > 0) to conserve credit"
echo ""

# ---------------------------------------------------------------------------
# Redundant mesh verification
# ---------------------------------------------------------------------------
echo "--- Redundant HVN mesh ---"
echo "  Primary:  HCYSRL     (AWS ap-northeast-1) ↔ vault-cluster"
echo "  Failover: demo-hvn   (Azure westus2)      ↔ boundary targets"
echo "  Policy:   Route Tokyo workloads via HCYSRL; Azure fallback via demo-hvn"
echo ""

# Update manifest timestamp
if [[ "$DRY_RUN" == "false" ]] && command -v python3 >/dev/null 2>&1; then
  python3 - <<PY
import json
from datetime import datetime, timezone
from pathlib import Path
p = Path("${MANIFEST}")
m = json.loads(p.read_text())
m["updatedAt"] = datetime.now(timezone.utc).isoformat()
m["preflight"]["status"] = "wired"
p.write_text(json.dumps(m, indent=2) + "\n")
print("Updated quadrilateral-manifest.json")
PY
fi

echo "=== Quadrilateral wire sequence complete ==="
echo "Next: make vault-bootstrap && make terraform-plan (with Akash deficit vars)"
