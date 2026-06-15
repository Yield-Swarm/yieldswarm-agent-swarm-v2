# Base agent read policy — runtime secrets for all agent workloads.
# For per-shard isolation, use scripts/create-shard-policies.sh.

path "yieldswarm/data/agents/runtime" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/agents/runtime" {
  capabilities = ["read", "list"]
}

path "yieldswarm/metadata/rpc" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}
