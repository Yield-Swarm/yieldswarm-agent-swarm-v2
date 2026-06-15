# =============================================================================
# Module: rpc-endpoints
# -----------------------------------------------------------------------------
# Pure projection: takes the `rpc` map fetched from Vault by the root module
# and exposes:
#
#   * `endpoint_urls` -- a chain-keyed map of public RPC URLs (no secrets).
#   * `secret_paths`  -- a chain-keyed map of Vault KV-v2 paths that hold the
#                        actual API keys for each chain. Akash workloads
#                        consume this via Vault Agent templating.
#
# Keeping URLs and secret paths separate means downstream Terraform/Akash
# never has to handle raw RPC keys; they only learn WHERE to ask Vault.
# =============================================================================

variable "endpoints" {
  description = "Decrypted Vault KV map keyed by chain name."
  type        = any
  sensitive   = true
}

locals {
  chains = ["solana", "ton", "tao", "helix", "zec", "erc4337"]
}

output "endpoint_urls" {
  value = {
    for c in local.chains :
    c => try(var.endpoints[c]["primary"], null)
  }
}

output "secret_paths" {
  value = {
    for c in local.chains :
    c => "yieldswarm/data/rpc/${c}"
  }
}

output "failover_endpoints" {
  value = {
    for c in local.chains :
    c => try(var.endpoints[c]["failover"], null)
  }
}
