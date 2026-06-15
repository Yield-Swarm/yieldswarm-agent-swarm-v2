output "api_key" {
  description = "Verified RunPod API key. Sensitive — propagate only via module composition."
  value       = var.credentials.api_key
  sensitive   = true
}

output "verified" {
  description = "True if a live API call to RunPod succeeded during the last plan."
  value       = var.verify_api_key
}
