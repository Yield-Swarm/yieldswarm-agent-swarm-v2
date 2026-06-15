# Policy: terraform-read
# Grants Terraform read-only access to the infrastructure secrets it needs to
# configure the Azure, RunPod, Vultr, DigitalOcean and RPC providers.
#
# The KV mount name is templated with the placeholder @@KV_MOUNT@@ and is
# substituted by infra/vault/bootstrap.sh at apply time (default: "secret").
#
# Principle of least privilege: Terraform can ONLY read the specific cloud
# provider credentials and RPC endpoints. It can never read the application
# runtime secrets (@@KV_MOUNT@@/data/yieldswarm/app) and can never write,
# list values, or delete anything.

# Cloud provider credentials (azure, runpod, vultr, digitalocean).
path "@@KV_MOUNT@@/data/yieldswarm/cloud/*" {
  capabilities = ["read"]
}

# Blockchain / RPC endpoints and keys.
path "@@KV_MOUNT@@/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

# Allow discovery of available secret names (metadata only, never values).
path "@@KV_MOUNT@@/metadata/yieldswarm/cloud/*" {
  capabilities = ["read", "list"]
}

path "@@KV_MOUNT@@/metadata/yieldswarm/rpc" {
  capabilities = ["read"]
}
