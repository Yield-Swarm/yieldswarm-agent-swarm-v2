# Read-only policy for CI validation and secret path audits.

path "auth/approle/login" {
  capabilities = ["create", "update"]
}

path "yieldswarm/data/*" {
  capabilities = ["read"]
}

path "yieldswarm/metadata/*" {
  capabilities = ["list", "read"]
}

path "sys/health" {
  capabilities = ["read"]
}
