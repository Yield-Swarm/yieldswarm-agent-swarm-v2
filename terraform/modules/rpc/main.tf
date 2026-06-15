# terraform/modules/rpc/main.tf
#
# Aggregates per-chain RPC config from Vault, asserts the required chains
# resolved, and surfaces them as typed outputs other modules can consume
# (e.g. for kubernetes_secret, akash deploy variables, dashboards).

locals {
  missing = [
    for c in var.required_chains :
    c if !contains(keys(var.endpoints), c) || try(var.endpoints[c]["url"], "") == ""
  ]
}

resource "terraform_data" "assert_required" {
  lifecycle {
    precondition {
      condition     = length(local.missing) == 0
      error_message = "Required RPC chains missing/empty in Vault: ${join(", ", local.missing)}. Run vault/scripts/seed-secrets.sh with the matching env vars set."
    }
  }
}
