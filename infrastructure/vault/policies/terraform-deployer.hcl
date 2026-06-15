# terraform-deployer.hcl
# Read-only access to the cloud-provider credentials and RPC endpoints that
# the Terraform pipeline needs to plan/apply infrastructure. No write access
# to KV; no access to wallet / signing material.

# Cloud provider credentials.
path "secret/data/yieldswarm/cloud/azure" {
  capabilities = ["read"]
}
path "secret/data/yieldswarm/cloud/runpod" {
  capabilities = ["read"]
}
path "secret/data/yieldswarm/cloud/vultr" {
  capabilities = ["read"]
}
path "secret/data/yieldswarm/cloud/digitalocean" {
  capabilities = ["read"]
}

# RPC endpoints + API keys consumed by infra/workload modules.
path "secret/data/yieldswarm/rpc/+" {
  capabilities = ["read"]
}

# Akash deployment seed data (provider config, deployer key handle).
path "secret/data/yieldswarm/akash/deployer" {
  capabilities = ["read"]
}

# Metadata listing so `terraform plan` can detect drift in version numbers
# (data-only; no value access).
path "secret/metadata/yieldswarm/cloud/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/yieldswarm/rpc/*" {
  capabilities = ["read", "list"]
}

# Self-token lifecycle (renew + revoke own token, no escalation).
path "auth/token/renew-self"  { capabilities = ["update"] }
path "auth/token/revoke-self" { capabilities = ["update"] }
path "sys/capabilities-self"  { capabilities = ["update"] }
