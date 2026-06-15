terraform {
  required_version = ">= 1.6.0"
}

variable "environment" {
  type = string
}

variable "chain_secrets" {
  description = "Map of chain name -> KV v2 payload pulled from Vault."
  type        = map(map(string))
  sensitive   = true
}

# The RPC module's job is to *validate* that each chain we care about
# has the fields its consumers expect, not to expose those secrets to
# downstream resources. Akash workloads read the same KV paths directly
# through Vault Agent at runtime; Terraform only enforces shape.

locals {
  required_fields = {
    solana = ["rpc_url"]
    eth    = ["rpc_url"]
    ton    = ["api_key"]
    tao    = ["subnet_key"]
    helix  = ["bridge_key"]
    zec    = ["shielded_key"]
  }

  missing = {
    for chain, fields in local.required_fields :
    chain => [for f in fields : f if !contains(keys(lookup(var.chain_secrets, chain, {})), f)]
    if length([for f in fields : f if !contains(keys(lookup(var.chain_secrets, chain, {})), f)]) > 0
  }
}

resource "terraform_data" "validate" {
  lifecycle {
    precondition {
      condition     = length(local.missing) == 0
      error_message = "Vault is missing required RPC fields: ${jsonencode(local.missing)}. Re-run infra/vault/bootstrap/30-seed-secrets.sh with the missing env vars set."
    }
  }
  input = keys(var.chain_secrets)
}

output "chain_inventory" {
  value = sort(keys(var.chain_secrets))
}
