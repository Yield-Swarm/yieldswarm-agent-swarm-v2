variable "environment" {
  type = string
}

variable "vault_kv_mount" {
  type = string
}

variable "rpc_secrets" {
  description = "Decoded KV-v2 data maps for each chain."
  type = object({
    solana = map(string)
    eth    = map(string)
    ton    = map(string)
    tao    = map(string)
  })
  sensitive = true
}
