output "vault_secret_paths" {
  description = "Vault paths read by this Terraform root. Secret values are never output."
  value       = var.vault_secret_paths
}

output "rpc_secret_keys" {
  description = "Names of RPC keys available to Terraform modules."
  value       = nonsensitive(keys(local.rpc_endpoints))
}
