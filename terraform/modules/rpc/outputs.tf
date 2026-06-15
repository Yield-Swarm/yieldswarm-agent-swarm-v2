output "endpoints" {
  description = "Validated RPC endpoints, keyed by chain. Sensitive."
  value       = var.endpoints
  sensitive   = true
  depends_on  = [terraform_data.assert_required]
}

output "urls" {
  description = "Chain -> RPC URL only. Sensitive (URLs may embed keys)."
  value = {
    for chain, cfg in var.endpoints : chain => try(cfg.url, null)
  }
  sensitive  = true
  depends_on = [terraform_data.assert_required]
}
