# =========================================================================
# ci-bootstrap.hcl
# -------------------------------------------------------------------------
# Tiny policy for CI whose ONLY purpose is to mint short-lived, response-
# wrapped SecretIDs for child AppRoles. CI itself can read nothing else.
# =========================================================================

path "auth/approle/role/terraform/secret-id" {
  capabilities      = ["update"]
  min_wrapping_ttl  = "60s"
  max_wrapping_ttl  = "300s"
}
path "auth/approle/role/terraform/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/akash-runtime/secret-id" {
  capabilities      = ["update"]
  min_wrapping_ttl  = "60s"
  max_wrapping_ttl  = "600s"
}
path "auth/approle/role/akash-runtime/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/integration-backend/secret-id" {
  capabilities      = ["update"]
  min_wrapping_ttl  = "60s"
  max_wrapping_ttl  = "600s"
}
path "auth/approle/role/integration-backend/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/bittensor-runtime/secret-id" {
  capabilities      = ["update"]
  min_wrapping_ttl  = "60s"
  max_wrapping_ttl  = "600s"
}
path "auth/approle/role/bittensor-runtime/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/odysseus-runtime/secret-id" {
  capabilities      = ["update"]
  min_wrapping_ttl  = "60s"
  max_wrapping_ttl  = "600s"
}
path "auth/approle/role/odysseus-runtime/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/payments-runtime/secret-id" {
  capabilities      = ["update"]
  min_wrapping_ttl  = "60s"
  max_wrapping_ttl  = "600s"
}
path "auth/approle/role/payments-runtime/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/multicloud-operator/secret-id" {
  capabilities      = ["update"]
  min_wrapping_ttl  = "60s"
  max_wrapping_ttl  = "600s"
}
path "auth/approle/role/multicloud-operator/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/beefcake-runtime/secret-id" {
  capabilities      = ["update"]
  min_wrapping_ttl  = "60s"
  max_wrapping_ttl  = "600s"
}
path "auth/approle/role/beefcake-runtime/role-id" {
  capabilities = ["read"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "auth/token/renew-self" {
  capabilities = ["update"]
}
