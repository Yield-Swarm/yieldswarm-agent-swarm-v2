path "cloud/data/azure" {
  capabilities = ["read"]
}

path "cloud/data/runpod" {
  capabilities = ["read"]
}

path "cloud/data/vultr" {
  capabilities = ["read"]
}

path "cloud/data/digitalocean" {
  capabilities = ["read"]
}

path "rpc/data/default" {
  capabilities = ["read"]
}

path "cloud/metadata/*" {
  capabilities = ["list"]
}

path "rpc/metadata/*" {
  capabilities = ["list"]
}
