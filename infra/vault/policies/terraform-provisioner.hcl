# =============================================================================
# Policy: terraform-provisioner
# Bound to the AppRole used by Terraform / CI to provision cloud infra.
# Grants READ-ONLY access to the cloud-provider and RPC credentials it needs
# to configure the azurerm, digitalocean, vultr and runpod providers.
# Principle of least privilege: NO write/delete, NO access to app/* secrets.
# =============================================================================

# KV v2 data plane (actual secret values) — read only.
path "kv/data/yieldswarm/cloud/azure" {
  capabilities = ["read"]
}
path "kv/data/yieldswarm/cloud/runpod" {
  capabilities = ["read"]
}
path "kv/data/yieldswarm/cloud/vultr" {
  capabilities = ["read"]
}
path "kv/data/yieldswarm/cloud/digitalocean" {
  capabilities = ["read"]
}

# RPC / blockchain endpoints consumed by provisioned infrastructure.
path "kv/data/yieldswarm/rpc/*" {
  capabilities = ["read"]
}

# KV v2 metadata plane — list/read versions for drift detection. No deletes.
path "kv/metadata/yieldswarm/cloud/*" {
  capabilities = ["read", "list"]
}
path "kv/metadata/yieldswarm/rpc/*" {
  capabilities = ["read", "list"]
}

# Allow the token to inspect and renew itself (needed for long applies).
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
