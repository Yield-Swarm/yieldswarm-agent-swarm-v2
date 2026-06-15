# Akash deployment runtime — read agent secrets only.
# Bound to AppRole: yieldswarm-akash
# Secret ID delivered at deploy time via wrapped token or secure channel.

path "yieldswarm/data/agents/runtime" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc" {
  capabilities = ["read"]
}

path "yieldswarm/data/runpod" {
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
