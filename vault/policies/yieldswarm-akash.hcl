# ============================================================
# Policy: yieldswarm-akash
# Scope : Runtime secret injection for Akash containers.
#         Grants read access to all paths required by the
#         Docker entrypoint to populate process environment.
#
#         Intended identity: AppRole role "yieldswarm-akash"
#         Token TTL: 24 h, renewable up to 168 h (7 days)
#         Secret ID TTL: 168 h — rotate on each SDL redeploy
# ============================================================

# Akash-specific deployment config
path "secret/data/yieldswarm/akash" {
  capabilities = ["read"]
}

# Agent runtime secrets
path "secret/data/yieldswarm/core" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/llm" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/blockchain" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/depin" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/integrations" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/monitoring" {
  capabilities = ["read"]
}

# List metadata only — never read other tenants' data
path "secret/metadata/yieldswarm/*" {
  capabilities = ["list"]
}

# Token lifecycle
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
