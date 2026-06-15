# Terraform can read only the provider credentials and RPC endpoints needed for
# infrastructure plans. It cannot write or delete secret data.

path "${kv_mount}/data/cloud/azure" {
  capabilities = ["read"]
}

path "${kv_mount}/data/cloud/runpod" {
  capabilities = ["read"]
}

path "${kv_mount}/data/cloud/vultr" {
  capabilities = ["read"]
}

path "${kv_mount}/data/cloud/digitalocean" {
  capabilities = ["read"]
}

path "${kv_mount}/data/rpc/*" {
  capabilities = ["read"]
}

path "${kv_mount}/metadata/cloud" {
  capabilities = ["list"]
}

path "${kv_mount}/metadata/rpc" {
  capabilities = ["list"]
}

path "${transit_mount}/encrypt/*" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
