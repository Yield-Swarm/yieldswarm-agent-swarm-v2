variable "vault_address" {
  description = "Vault server address. Defaults to VAULT_ADDR env var."
  type        = string
  default     = ""
}

variable "kv_mount_path" {
  description = "Path of the KVv2 mount that holds all YieldSwarm application secrets."
  type        = string
  default     = "yieldswarm"
}

variable "transit_mount_path" {
  description = "Path of the transit secrets engine used for envelope encryption."
  type        = string
  default     = "transit"
}

variable "transit_keys" {
  description = "Named transit keys to create."
  type        = list(string)
  default     = ["terraform-state", "agent-runtime"]
}

variable "akash_egress_cidrs" {
  description = "CIDR list of Akash provider egress IPs allowed to use the akash-runtime AppRole. Lock this down per provider."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ci_egress_cidrs" {
  description = "CIDR list of CI runner egress IPs allowed to use ci-bootstrap. GitHub-hosted runners change daily, so leave 0.0.0.0/0 if you cannot pin."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "agent_runtime_cidrs" {
  description = "CIDR list of trusted on-prem / Vercel / Azure agent shard egress IPs."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "audit_file_path" {
  description = "Absolute path on each Vault node where the file audit device writes."
  type        = string
  default     = "/var/log/vault/audit.log"
}

variable "enable_oidc" {
  description = "Whether to enable an OIDC auth backend for human admins."
  type        = bool
  default     = false
}

variable "oidc" {
  description = "OIDC configuration (only used when enable_oidc=true)."
  type = object({
    discovery_url    = string
    client_id        = string
    client_secret    = string
    allowed_redirect = list(string)
    admin_group      = string
  })
  default = {
    discovery_url    = ""
    client_id        = ""
    client_secret    = ""
    allowed_redirect = []
    admin_group      = ""
  }
  sensitive = true
}
