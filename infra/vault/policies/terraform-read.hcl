path "kv/data/infra/providers/*" {
  capabilities = ["read"]
}

path "kv/metadata/infra/providers/*" {
  capabilities = ["read", "list"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
