variable "kv_mount" {
  description = "KV v2 mount that holds the YieldSwarm secrets (matches vault/scripts/bootstrap.sh)."
  type        = string
  default     = "yieldswarm"
}

variable "rpc_chains" {
  description = "Subset of RPC chains to fetch from Vault. Each maps to yieldswarm/rpc/<name>."
  type        = list(string)
  default     = ["solana", "ethereum", "ton", "bittensor"]
}
