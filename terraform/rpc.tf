# =============================================================================
# RPC Endpoint References
# YieldSwarm AgentSwarm OS v2.0
#
# RPC endpoints are fetched from Vault (vault-data.tf) and surfaced as
# Terraform outputs so they can be consumed by other modules or CI scripts.
# No infrastructure is provisioned here — RPC endpoints are SaaS services.
#
# To verify the secrets are present:
#   terraform output rpc_primary_url
# =============================================================================

# Sentinel check: fail loudly if a required RPC key is missing from Vault.
# This prevents deploying infra that would silently lack a working RPC URL.
resource "null_resource" "rpc_secrets_present" {
  # Force re-evaluation on every plan so stale secrets don't go unnoticed.
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      if [ -z "${data.vault_kv_secret_v2.rpc_solana.data["primary_url"]}" ]; then
        echo "ERROR: secret/yieldswarm/${var.vault_environment}/rpc/solana.primary_url is empty" >&2
        exit 1
      fi
      if [ -z "${data.vault_kv_secret_v2.rpc_solana.data["helius_api_key"]}" ]; then
        echo "ERROR: secret/yieldswarm/${var.vault_environment}/rpc/solana.helius_api_key is empty" >&2
        exit 1
      fi
      echo "RPC secrets validation passed."
    EOT
  }
}
