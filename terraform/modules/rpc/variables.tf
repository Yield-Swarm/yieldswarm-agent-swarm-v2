variable "endpoints" {
  description = <<-EOT
    Per-chain RPC config as returned by module.vault_secrets.rpc.
    Shape: map(string => map(string,string)). Each inner map contains at minimum
    a "url" key and optional API key fields (helius_api_key, birdeye_api_key,
    jupiter_api_key, alchemy_api_key, infura_project_id, ...).
  EOT
  type        = map(map(string))
  sensitive   = true
}

variable "required_chains" {
  description = "Chains that MUST be present and have a non-empty URL. Fails plan otherwise."
  type        = list(string)
  default     = ["solana"]
}
