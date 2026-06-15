# Chainlink vault management requires RPC endpoints and signing material, but
# does not need cloud-provider API tokens or broad application secrets.
path "secret/data/yieldswarm/core" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/rpc" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/blockchain/signing" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/yield/chainlink" {
  capabilities = ["read"]
}

path "transit/encrypt/yieldswarm-wallet" {
  capabilities = ["update"]
}

path "transit/decrypt/yieldswarm-wallet" {
  capabilities = ["update"]
}
