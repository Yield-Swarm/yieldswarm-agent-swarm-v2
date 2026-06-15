variable "credentials" {
  description = "RunPod API credentials (pipe from module.vault_secrets.runpod)."
  type = object({
    api_key = string
  })
  sensitive = true

  validation {
    condition     = var.credentials.api_key != null && length(var.credentials.api_key) > 16
    error_message = "RunPod api_key missing or implausibly short. Seed Vault with RUNPOD_API_KEY set."
  }
}

variable "verify_api_key" {
  description = "When true, performs a live GraphQL call to RunPod to verify the key during plan."
  type        = bool
  default     = true
}
