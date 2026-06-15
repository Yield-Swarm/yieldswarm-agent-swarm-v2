output "resolved_path" {
  value = vault_kv_secret_v2.resolved.path
}

output "chains" {
  value = keys(local.resolved)
}
