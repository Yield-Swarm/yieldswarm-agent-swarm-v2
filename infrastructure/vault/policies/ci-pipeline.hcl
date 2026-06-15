# ci-pipeline.hcl
# Used by the CI runner to mint short-lived secret_ids for the
# terraform-deployer and akash-workload AppRoles. Cannot read application
# secrets directly.

path "auth/approle/role/terraform-deployer/secret-id" {
  capabilities = ["update"]
  min_wrapping_ttl = "10s"
  max_wrapping_ttl = "300s"
}

path "auth/approle/role/akash-workload/secret-id" {
  capabilities = ["update"]
  min_wrapping_ttl = "10s"
  max_wrapping_ttl = "300s"
}

# Read-only on role-ids so CI can ship them as non-secret config.
path "auth/approle/role/terraform-deployer/role-id" {
  capabilities = ["read"]
}
path "auth/approle/role/akash-workload/role-id" {
  capabilities = ["read"]
}

# Self lifecycle.
path "auth/token/renew-self"  { capabilities = ["update"] }
path "auth/token/revoke-self" { capabilities = ["update"] }
path "sys/capabilities-self"  { capabilities = ["update"] }
