# Read Node 5 Stellar + Cosmos secrets (SecretProd.pdf → Vault)
path "secret/data/yieldswarm/node5/stellar" {
  capabilities = ["read"]
}

path "secret/data/yieldswarm/node5/cosmos" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/node5/stellar" {
  capabilities = ["read"]
}

path "secret/metadata/yieldswarm/node5/cosmos" {
  capabilities = ["read"]
}
