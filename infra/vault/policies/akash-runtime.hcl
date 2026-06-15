path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

path "${runtime_mount}/data/${application_name}/${environment}" {
  capabilities = ["read"]
}

path "${runtime_mount}/metadata/${application_name}" {
  capabilities = ["list"]
}

path "${runtime_mount}/metadata/${application_name}/${environment}" {
  capabilities = ["read", "list"]
}
