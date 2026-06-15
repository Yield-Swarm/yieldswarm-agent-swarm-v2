# =============================================================================
# Vault Policy: rpc-readonly
# YieldSwarm AgentSwarm OS v2.0
#
# Read-only access to all RPC endpoints and blockchain keys.
# Suitable for any service that only needs to query chains.
# =============================================================================

path "secret/data/yieldswarm/+/rpc/*" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/rpc/*" {
  capabilities = ["read", "list"]
}

path "secret/data/yieldswarm/+/blockchain/keys" {
  capabilities = ["read"]
}
path "secret/metadata/yieldswarm/+/blockchain/keys" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
