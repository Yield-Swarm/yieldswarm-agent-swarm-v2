## agent-readonly policy
## For internal agents (akash-optimizer, openclaw-scaler, chainlink-vault-manager)
## running on operator-controlled infrastructure.  Strictly read + transit ops.

path "kv/data/yieldswarm/+/app/*" { capabilities = ["read"] }
path "kv/data/yieldswarm/+/rpc/*" { capabilities = ["read"] }

path "transit/encrypt/wallet-encryption" { capabilities = ["update"] }
path "transit/decrypt/wallet-encryption" { capabilities = ["update"] }

path "auth/token/renew-self"  { capabilities = ["update"] }
path "auth/token/revoke-self" { capabilities = ["update"] }
path "sys/capabilities-self"  { capabilities = ["update"] }
