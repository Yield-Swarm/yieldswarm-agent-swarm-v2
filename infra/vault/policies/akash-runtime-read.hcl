# Akash runtime may only read the single runtime secret document.
path "app-secrets/data/akash/runtime" {
  capabilities = ["read"]
}

path "app-secrets/metadata/akash/runtime" {
  capabilities = ["read"]
}
