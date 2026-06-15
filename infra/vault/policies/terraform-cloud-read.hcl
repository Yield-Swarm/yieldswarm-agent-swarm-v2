# Terraform may only read cloud provider and RPC secrets.
path "cloud-secrets/data/terraform/azure" {
  capabilities = ["read"]
}

path "cloud-secrets/data/terraform/runpod" {
  capabilities = ["read"]
}

path "cloud-secrets/data/terraform/vultr" {
  capabilities = ["read"]
}

path "cloud-secrets/data/terraform/digitalocean" {
  capabilities = ["read"]
}

path "cloud-secrets/data/terraform/rpc" {
  capabilities = ["read"]
}

path "cloud-secrets/metadata/terraform/*" {
  capabilities = ["read", "list"]
}
