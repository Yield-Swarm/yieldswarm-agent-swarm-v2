# Akash workloads read only runtime application, GPU provider, selected cloud,
# and RPC secrets. They do not receive Azure provisioning credentials.

path "${kv_mount}/data/app/agentswarm" {
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

path "${transit_mount}/decrypt/${transit_key}" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
