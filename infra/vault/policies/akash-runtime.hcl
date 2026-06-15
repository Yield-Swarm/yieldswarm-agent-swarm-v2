## akash-runtime policy
## Applied to workloads running on Akash providers.  Vault Agent inside the
## container authenticates with AppRole (role_id baked into image, secret_id
## delivered response-wrapped at deploy time) and renders secrets into a
## tmpfs file consumed by the application entrypoint.
##
## NOTE: paths are scoped to a single environment determined by the role
## binding (templated via `secret_id_metadata` at role creation time).

# Application secrets the agent needs at runtime
path "kv/data/yieldswarm/+/app/agentswarm" { capabilities = ["read"] }
path "kv/data/yieldswarm/+/rpc/*"          { capabilities = ["read"] }
path "kv/data/yieldswarm/+/akash"          { capabilities = ["read"] }

# RunPod / Vultr / DO read-only IF this workload provisions sub-resources.
path "kv/data/yieldswarm/+/runpod"         { capabilities = ["read"] }
path "kv/data/yieldswarm/+/vultr"          { capabilities = ["read"] }
path "kv/data/yieldswarm/+/digitalocean"   { capabilities = ["read"] }

# Encrypt/decrypt wallet payloads without ever pulling the key out of Vault
path "transit/encrypt/wallet-encryption" { capabilities = ["update"] }
path "transit/decrypt/wallet-encryption" { capabilities = ["update"] }
path "transit/sign/tee-signing"          { capabilities = ["update"] }
path "transit/verify/tee-signing"        { capabilities = ["update"] }

# Lease management
path "auth/token/renew-self"  { capabilities = ["update"] }
path "auth/token/revoke-self" { capabilities = ["update"] }
path "sys/leases/renew"       { capabilities = ["update"] }
path "sys/capabilities-self"  { capabilities = ["update"] }
