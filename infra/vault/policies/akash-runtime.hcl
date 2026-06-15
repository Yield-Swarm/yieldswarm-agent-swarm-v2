path "kv/data/runtime/akash/*" {
  capabilities = ["read"]
}

path "kv/metadata/runtime/akash/*" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
