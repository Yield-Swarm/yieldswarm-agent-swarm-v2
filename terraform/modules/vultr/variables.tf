variable "credentials" {
  description = "Vultr API credentials (pipe from module.vault_secrets.vultr)."
  type = object({
    api_key = string
  })
  sensitive = true

  validation {
    condition     = var.credentials.api_key != null && length(var.credentials.api_key) >= 32
    error_message = "Vultr api_key missing or too short. Seed Vault with VULTR_API_KEY set."
  }
}

variable "rate_limit" {
  description = "Vultr API rate limit (requests/second)."
  type        = number
  default     = 1
}

variable "retry_limit" {
  description = "Vultr API retry limit on 5xx."
  type        = number
  default     = 3
}
