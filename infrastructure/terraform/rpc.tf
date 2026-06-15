# =============================================================================
# RPC distribution.
#
# Vault is the single source of truth for RPC endpoints + provider keys.
# Terraform mirrors them into:
#
#   * a sensitive output (consumed by the Akash deployment pipeline)
#   * Azure Key Vault (azure.tf, when Azure is enabled)
#   * a DigitalOcean Spaces object encrypted with the cluster KMS, used as
#     last-resort cold storage. Optional, gated by DO being enabled.
#
# Nothing here ever logs raw values; outputs are marked sensitive.
# =============================================================================

locals {
  rpc_keys = [
    "solana_rpc_url",
    "helius_api_key",
    "jupiter_api_key",
    "birdeye_api_key",
    "raydium_api_key",
    "ton_api_key",
    "tao_subnet_key",
    "helix_chain_bridge_key",
    "zec_shielded_key",
    "erc4337_bundler_key",
  ]

  # Subset of rpc data limited to known keys (drops anything unexpected so a
  # malicious Vault write cannot smuggle extra fields downstream).
  rpc_safe = { for k in local.rpc_keys : k => try(local.rpc_secret[k], "") }
}

# Optional: ship the bundle to a DO Spaces object so the OpenClaw workers can
# pull it via a presigned URL if Vault is briefly unreachable.
resource "digitalocean_spaces_bucket_object" "rpc_bundle" {
  count = var.enabled_clouds.digitalocean ? 1 : 0

  region       = digitalocean_spaces_bucket.cron_artifacts[0].region
  bucket       = digitalocean_spaces_bucket.cron_artifacts[0].name
  key          = "rpc/${var.environment}/bundle.json"
  content      = jsonencode(local.rpc_safe)
  content_type = "application/json"
  acl          = "private"

  # Force re-upload when source secret rotates. We embed a sha256 over the
  # bundle so any value change triggers a new object version automatically.
  metadata = {
    rpc_fingerprint = sha256(jsonencode(local.rpc_safe))
  }
}
