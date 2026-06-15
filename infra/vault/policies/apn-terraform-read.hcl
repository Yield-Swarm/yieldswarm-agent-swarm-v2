# apn-terraform-read: policy bound to the `apn-terraform` AppRole.
#
# Terraform pulls cloud provider credentials and RPC secrets from Vault
# at plan / apply time. It must never be able to *write* secrets back,
# rotate them, or read anything outside the apn provider tree.

# Provider credentials needed by the Terraform root module.
path "kv/data/apn/azure" {
  capabilities = ["read"]
}

path "kv/data/apn/runpod" {
  capabilities = ["read"]
}

path "kv/data/apn/vultr" {
  capabilities = ["read"]
}

path "kv/data/apn/digitalocean" {
  capabilities = ["read"]
}

# RPC endpoints + chain API keys. Globbed so we can add chains without
# editing this policy, but still scoped to the rpc subtree.
path "kv/data/apn/rpc/*" {
  capabilities = ["read"]
}

# Metadata reads let `terraform plan` detect version drift without
# exposing secret payloads.
path "kv/metadata/apn/azure" {
  capabilities = ["read"]
}

path "kv/metadata/apn/runpod" {
  capabilities = ["read"]
}

path "kv/metadata/apn/vultr" {
  capabilities = ["read"]
}

path "kv/metadata/apn/digitalocean" {
  capabilities = ["read"]
}

path "kv/metadata/apn/rpc/*" {
  capabilities = ["read", "list"]
}

# Self-renew and self-revoke for short-lived Terraform tokens.
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/revoke-self" {
  capabilities = ["update"]
}

path "sys/capabilities-self" {
  capabilities = ["update"]
}
