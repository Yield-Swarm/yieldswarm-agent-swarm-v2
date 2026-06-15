path "app/data/akash" {
  capabilities = ["read"]
}

path "rpc/data/default" {
  capabilities = ["read"]
}

path "app/metadata/*" {
  capabilities = ["list"]
}

path "rpc/metadata/*" {
  capabilities = ["list"]
}
