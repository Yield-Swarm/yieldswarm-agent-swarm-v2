output "terraform_cloud_workspace" {
  description = "Terraform Cloud workspace used by this stack."
  value       = "Helixchainprod"
}

output "akash_targeting" {
  description = "Akash targeting metadata from the null resource."
  value = {
    node      = var.akash_node
    chain_id  = var.akash_chain_id
    key_name  = var.akash_key_name
    gpu_model = var.akash_gpu_model_hint
  }
}

output "azure_fallback_vmss_id" {
  description = "VMSS resource id when Azure fallback is enabled."
  value       = var.enable_azure_fallback ? azurerm_linux_virtual_machine_scale_set.fallback[0].id : null
}
