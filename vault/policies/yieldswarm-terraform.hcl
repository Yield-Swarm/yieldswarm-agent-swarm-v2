# ============================================================
# Policy: yieldswarm-terraform
# Scope : Read-only access to all YieldSwarm secrets for
#         Terraform provider authentication and infrastructure
#         provisioning pipelines.
#
#         Intended identity: AppRole role "yieldswarm-terraform"
#         Token TTL: 1 h (short — regenerate per plan/apply run)
# ============================================================

# Cloud provider credential paths
path "secret/data/yieldswarm/azure" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/runpod" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/vultr" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/do" {
  capabilities = ["read"]
}

# RPC endpoints used in infrastructure configs
path "secret/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

# Integration credentials (GitHub, Vercel, Notion, Linear)
path "secret/data/yieldswarm/integrations" {
  capabilities = ["read"]
}

# Monitoring / observability credentials
path "secret/data/yieldswarm/monitoring" {
  capabilities = ["read"]
}

# List metadata (for debugging / audit, no secret data exposed)
path "secret/metadata/yieldswarm/*" {
  capabilities = ["list"]
}

# Token self-management
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
