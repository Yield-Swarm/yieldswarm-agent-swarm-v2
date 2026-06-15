path "kv-runtime/data/akash/*" {
  capabilities = ["read"]
}

path "kv-runtime/metadata/akash/*" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
