###############################################################################
# Root module outputs: capacity plan + per-provider results.
###############################################################################

output "fallback_deficit" {
  description = "Number of worker units the fallback fleet is sized to cover."
  value       = local.fallback_deficit
}

output "planned_worker_counts" {
  description = "Worker units assigned to each enabled provider."
  value       = local.worker_counts
}

output "provisioned_worker_total" {
  description = "Total fallback workers actually provisioned (may slightly exceed the deficit due to rounding up per provider)."
  value       = local.azure_workers + local.gcp_workers + local.runpod_workers + local.vultr_workers
}

output "azure" {
  description = "Azure VMSS fallback details."
  value       = length(module.azure_vmss) > 0 ? module.azure_vmss[0].summary : null
}

output "gcp" {
  description = "GCP MIG fallback details."
  value       = length(module.gcp_mig) > 0 ? module.gcp_mig[0].summary : null
}

output "runpod" {
  description = "RunPod fallback details."
  value       = length(module.runpod) > 0 ? module.runpod[0].summary : null
}

output "vultr" {
  description = "Vultr fallback details."
  value       = length(module.vultr) > 0 ? module.vultr[0].summary : null
}

output "breakglass_private_key_pem" {
  description = "PEM private key for break-glass SSH access, generated only when no ssh_public_key was supplied. Store it in a secret manager."
  value       = length(tls_private_key.breakglass) > 0 ? tls_private_key.breakglass[0].private_key_pem : null
  sensitive   = true
}
