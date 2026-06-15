## terraform-cicd policy
## Used by GitHub Actions / CI pipelines that run `terraform plan`/`apply`.
## Read-only on cloud credentials + state-locking metadata.  No write access
## to KV; that is reserved for `operator`.

# Cloud provider creds (read-only)
path "kv/data/yieldswarm/+/azure"        { capabilities = ["read"] }
path "kv/data/yieldswarm/+/runpod"       { capabilities = ["read"] }
path "kv/data/yieldswarm/+/vultr"        { capabilities = ["read"] }
path "kv/data/yieldswarm/+/digitalocean" { capabilities = ["read"] }

# RPC endpoints (read-only, recursive)
path "kv/data/yieldswarm/+/rpc/*" { capabilities = ["read"] }

# Akash chain credentials (read-only) - used by `terraform-provider-akash`.
path "kv/data/yieldswarm/+/akash" { capabilities = ["read"] }

# Metadata listing so plans can detect drift
path "kv/metadata/yieldswarm/+/*" { capabilities = ["list", "read"] }

# Terraform state lock via Vault (optional, when using `vault` backend)
path "kv/data/tfstate-locks/*"     { capabilities = ["create", "read", "update", "delete"] }
path "kv/metadata/tfstate-locks/*" { capabilities = ["list", "read", "delete"] }

# Encryption-as-a-service for sensitive Terraform outputs
path "transit/encrypt/tf-outputs" { capabilities = ["update"] }
path "transit/decrypt/tf-outputs" { capabilities = ["update"] }

# Self-management
path "auth/token/renew-self"  { capabilities = ["update"] }
path "auth/token/revoke-self" { capabilities = ["update"] }
path "sys/capabilities-self"  { capabilities = ["update"] }
