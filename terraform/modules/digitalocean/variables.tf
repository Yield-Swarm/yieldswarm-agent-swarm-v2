variable "credentials" {
  description = "DigitalOcean API + Spaces credentials (from module.vault_secrets.digitalocean)."
  type = object({
    token             = string
    spaces_access_id  = string
    spaces_secret_key = string
  })
  sensitive = true

  validation {
    condition     = var.credentials.token != null && length(var.credentials.token) >= 40
    error_message = "DigitalOcean token missing or too short. Seed Vault with DIGITALOCEAN_TOKEN set."
  }
}

variable "default_region" {
  description = "Default DO region for Droplets/Spaces."
  type        = string
  default     = "nyc3"
}
