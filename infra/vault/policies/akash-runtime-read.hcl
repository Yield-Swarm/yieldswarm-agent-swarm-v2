# Policy: akash-runtime-read
# Grants the Akash-hosted runtime container read-only access to the application
# secrets and RPC endpoints it must inject as environment variables at startup.
#
# The KV mount name is templated with the placeholder @@KV_MOUNT@@ and is
# substituted by infra/vault/bootstrap.sh at apply time (default: "secret").
#
# Principle of least privilege: the runtime can ONLY read the application bundle
# and RPC endpoints. It can never read raw cloud provider IaC credentials
# (@@KV_MOUNT@@/data/yieldswarm/cloud/*) and can never write or delete.

# Application runtime secret bundle (LLM keys, wallet keys, integration tokens).
path "@@KV_MOUNT@@/data/yieldswarm/app" {
  capabilities = ["read"]
}

# Blockchain / RPC endpoints and keys.
path "@@KV_MOUNT@@/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

# Allow the token to look up and renew itself so long-lived deployments can
# keep a valid lease without escalating privileges.
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
