# Terraform CI/CD read-only access to cloud provider and RPC secrets.
# Scoped to the minimum paths required by terraform/providers.tf.

path "yieldswarm/data/azure" {
  capabilities = ["read"]
}

path "yieldswarm/data/runpod" {
  capabilities = ["read"]
}

path "yieldswarm/data/vultr" {
  capabilities = ["read"]
}

path "yieldswarm/data/digitalocean" {
  capabilities = ["read"]
}

path "yieldswarm/data/rpc" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
