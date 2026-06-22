# =========================================================================
# terraform.hcl
# -------------------------------------------------------------------------
# Granted to the AppRole that Terraform uses to provision YieldSwarm
# infrastructure (Azure, RunPod, Vultr, DigitalOcean, RPC providers).
#
# It is read-only against KVv2, scoped strictly to the provider sub-paths
# Terraform needs. Terraform does NOT have write capability on KV - secret
# rotation is handled by the dedicated `secret-rotator` workflow with its
# own policy.
# =========================================================================

# --- KVv2 reads (data path) ---------------------------------------------
# Cloud provider creds
path "yieldswarm/data/cloud/azure" {
  capabilities = ["read"]
}
path "yieldswarm/data/cloud/runpod" {
  capabilities = ["read"]
}
path "yieldswarm/data/cloud/vultr" {
  capabilities = ["read"]
}
path "yieldswarm/data/cloud/digitalocean" {
  capabilities = ["read"]
}
path "yieldswarm/data/cloud/vast" {
  capabilities = ["read"]
}
path "yieldswarm/data/cloud/gcp" {
  capabilities = ["read"]
}
path "yieldswarm/data/cloud/aws" {
  capabilities = ["read"]
}
path "yieldswarm/data/cloud/alibaba" {
  capabilities = ["read"]
}
path "yieldswarm/data/cloud/akash" {
  capabilities = ["read"]
}

path "yieldswarm/data/cloud/cherry" {
  capabilities = ["read"]
}
path "yieldswarm/data/providers/cherry" {
  capabilities = ["read"]
}

# RPC / chain provider creds (Helius, Birdeye, Solana, etc.)
path "yieldswarm/data/rpc/+" {
  capabilities = ["read"]
}

# Terraform remote-state encryption key (transit) - never sees raw key.
path "transit/encrypt/terraform-state" {
  capabilities = ["update"]
}
path "transit/decrypt/terraform-state" {
  capabilities = ["update"]
}

# --- KVv2 metadata (needed by `terraform plan` to detect drift) ---------
path "yieldswarm/metadata/cloud/*" {
  capabilities = ["read", "list"]
}
path "yieldswarm/metadata/rpc/*" {
  capabilities = ["read", "list"]
}

path "yieldswarm/metadata/providers/cherry" {
  capabilities = ["read", "list"]
}

# --- Token hygiene -------------------------------------------------------
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Explicit deny on everything else (defence in depth)
path "yieldswarm/data/akash/*" {
  capabilities = ["deny"]
}
path "yieldswarm/data/agents/*" {
  capabilities = ["deny"]
}
path "sys/*" {
  capabilities = ["deny"]
}
