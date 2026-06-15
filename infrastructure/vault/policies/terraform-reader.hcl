# =============================================================================
# Policy: terraform-reader
# Purpose: Read-only access for the Terraform AppRole to pull infrastructure
#          secrets (Azure, RunPod, Vultr, DigitalOcean, RPC endpoints).
# Mount  : kv/ (KV v2)
# =============================================================================

# --- Infrastructure provider credentials -------------------------------------
path "kv/data/yieldswarm/infra/azure" {
  capabilities = ["read"]
}

path "kv/data/yieldswarm/infra/runpod" {
  capabilities = ["read"]
}

path "kv/data/yieldswarm/infra/vultr" {
  capabilities = ["read"]
}

path "kv/data/yieldswarm/infra/digitalocean" {
  capabilities = ["read"]
}

# --- RPC / chain endpoints ----------------------------------------------------
path "kv/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

# --- Metadata (versioning, list) so `terraform plan` can detect drift --------
path "kv/metadata/yieldswarm/infra/*" {
  capabilities = ["read", "list"]
}

path "kv/metadata/yieldswarm/rpc" {
  capabilities = ["read", "list"]
}

# --- Token self-management ----------------------------------------------------
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

# --- Deny everything else (defense in depth) ---------------------------------
path "sys/*" {
  capabilities = ["deny"]
}
