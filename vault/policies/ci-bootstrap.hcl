# =========================================================================
# ci-bootstrap.hcl
# -------------------------------------------------------------------------
# Tiny policy attached to the AppRole used by CI (GitHub Actions, etc.)
# whose ONLY purpose is to mint short-lived child tokens for terraform,
# akash, or agent-runtime via the role-bound AppRoles below. CI itself
# can read nothing else.
# =========================================================================

# Allow CI to fetch a wrapped SecretID for the terraform AppRole so it
# can drive `terraform plan/apply` with a fresh, ephemeral identity.
path "auth/approle/role/terraform/secret-id" {
  capabilities = ["update"]
  min_wrapping_ttl    = "60s"
  max_wrapping_ttl    = "300s"
}

path "auth/approle/role/terraform/role-id" {
  capabilities = ["read"]
}

# Same for the Akash deployer AppRole. The wrapped SecretID is injected
# as an Akash deployment env-var; the workload unwraps it once on start.
path "auth/approle/role/akash-runtime/secret-id" {
  capabilities = ["update"]
  min_wrapping_ttl    = "60s"
  max_wrapping_ttl    = "600s"
}

path "auth/approle/role/akash-runtime/role-id" {
  capabilities = ["read"]
}

# Lookup own token only (so CI can renew/inspect itself)
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

path "auth/token/renew-self" {
  capabilities = ["update"]
}
