path "${kv_mount_path}/metadata/platform" {
  capabilities = ["list", "read"]
}

path "${kv_mount_path}/metadata/platform/*" {
  capabilities = ["list", "read"]
}

path "${kv_mount_path}/data/platform/azure" {
  capabilities = ["read"]
}

path "${kv_mount_path}/data/platform/runpod" {
  capabilities = ["read"]
}

path "${kv_mount_path}/data/platform/vultr" {
  capabilities = ["read"]
}

path "${kv_mount_path}/data/platform/digitalocean" {
  capabilities = ["read"]
}

path "${kv_mount_path}/data/platform/rpc" {
  capabilities = ["read"]
}
