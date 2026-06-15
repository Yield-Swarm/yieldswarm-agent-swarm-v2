path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

path "${platform_mount}/data/${environment}/azure" {
  capabilities = ["read"]
}

path "${platform_mount}/data/${environment}/runpod" {
  capabilities = ["read"]
}

path "${platform_mount}/data/${environment}/vultr" {
  capabilities = ["read"]
}

path "${platform_mount}/data/${environment}/digitalocean" {
  capabilities = ["read"]
}

path "${platform_mount}/data/${environment}/rpc" {
  capabilities = ["read"]
}

path "${platform_mount}/metadata/${environment}" {
  capabilities = ["list"]
}

path "${platform_mount}/metadata/${environment}/*" {
  capabilities = ["read", "list"]
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
