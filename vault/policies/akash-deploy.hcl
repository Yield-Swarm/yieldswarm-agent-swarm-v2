# Akash deployment policy — SDL signing and runtime secret-id generation.

path "secret/data/yieldswarm/akash/deploy" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/akash/deploy" {
  capabilities = ["read", "list"]
}

path "auth/approle/role/akash-runtime/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/akash-runtime/secret-id" {
  capabilities = ["update"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
