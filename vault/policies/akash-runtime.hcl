# vault/policies/akash-runtime.hcl
# Attached to the AppRole that the Akash workload uses at runtime.
# Strictly read-only over the secret paths the running container needs.
#
# The container reads via vault-agent which renders an env file from these paths.
# It does NOT receive a long-lived token — it uses a wrapped Secret ID delivered
# at deploy time (see akash/entrypoint.sh and SECRETS.md §"Akash AppRole").

path "yieldswarm/data/runtime/core"        { capabilities = ["read"] }
path "yieldswarm/data/runtime/llm"         { capabilities = ["read"] }
path "yieldswarm/data/runtime/wallets"     { capabilities = ["read"] }
path "yieldswarm/data/rpc/*"               { capabilities = ["read"] }
path "yieldswarm/data/integrations/*"      { capabilities = ["read"] }

# Allow listing inside runtime/ so the agent template can iterate optional keys.
path "yieldswarm/metadata/runtime/*"       { capabilities = ["read","list"] }
path "yieldswarm/metadata/rpc/*"           { capabilities = ["read","list"] }
path "yieldswarm/metadata/integrations/*"  { capabilities = ["read","list"] }

# Transit encrypt/decrypt for wallet ops (no key export).
path "transit/encrypt/wallet"              { capabilities = ["update"] }
path "transit/decrypt/wallet"              { capabilities = ["update"] }

# Token lifecycle.
path "auth/token/lookup-self"              { capabilities = ["read"] }
path "auth/token/renew-self"               { capabilities = ["update"] }
path "auth/token/revoke-self"              { capabilities = ["update"] }
path "sys/capabilities-self"               { capabilities = ["update"] }
