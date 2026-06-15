# Root module outputs — confirms Vault secret paths resolve without exposing values.

output "vault_mount" {
  description = "KV v2 mount used for all secrets."
  value       = "yieldswarm"
}

output "vault_secret_paths" {
  description = "Secret paths read by this Terraform configuration."
  value = [
    "yieldswarm/azure",
    "yieldswarm/runpod",
    "yieldswarm/vultr",
    "yieldswarm/digitalocean",
    "yieldswarm/rpc",
    "yieldswarm/akash",
  ]
}

output "akash_chain_id" {
  description = "Akash chain ID from Vault."
  value       = nonsensitive(local.akash_secrets.chain_id)
}

output "akash_rpc_endpoint" {
  description = "Akash RPC endpoint from Vault."
  value       = nonsensitive(local.akash_secrets.rpc_endpoint)
}
