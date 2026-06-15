# vault/policies/terraform.hcl
# Policy attached to the AppRole that Terraform (CI or operator) uses.
# Read-only over the provider credential paths Terraform needs to plan/apply.
#
# KV v2 layout (mount = "yieldswarm"):
#   yieldswarm/data/providers/azure
#   yieldswarm/data/providers/runpod
#   yieldswarm/data/providers/vultr
#   yieldswarm/data/providers/digitalocean
#   yieldswarm/data/rpc/<chain>
#
# KV v2 requires "data/" in the request path even though the human-friendly
# path is "yieldswarm/providers/azure".

path "yieldswarm/data/providers/azure" {
  capabilities = ["read"]
}

path "yieldswarm/data/providers/runpod" {
  capabilities = ["read"]
}

path "yieldswarm/data/providers/vultr" {
  capabilities = ["read"]
}

path "yieldswarm/data/providers/digitalocean" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc/*" {
  capabilities = ["read"]
}

# Metadata reads are needed for Terraform's vault_kv_secret_v2 data source
# to resolve the current version.
path "yieldswarm/metadata/providers/*" {
  capabilities = ["read","list"]
}

path "yieldswarm/metadata/rpc/*" {
  capabilities = ["read","list"]
}

# Token self-management (renew / lookup) — required for any long-running plan.
path "auth/token/lookup-self"   { capabilities = ["read"] }
path "auth/token/renew-self"    { capabilities = ["update"] }
path "auth/token/revoke-self"   { capabilities = ["update"] }
path "sys/capabilities-self"    { capabilities = ["update"] }
