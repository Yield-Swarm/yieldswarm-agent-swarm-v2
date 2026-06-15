# vault/policies/ci.hcl
# Policy for the GitHub Actions / GitLab CI runner that executes terraform plan/apply.
# Identical to terraform.hcl in surface area, but a separate role lets us rotate
# CI-issued Secret IDs independently from operator-issued ones, and lets us
# bind CIDR / token TTL constraints differently in approle/role/ci.

path "yieldswarm/data/providers/*"    { capabilities = ["read"] }
path "yieldswarm/data/rpc/*"          { capabilities = ["read"] }
path "yieldswarm/metadata/providers/*" { capabilities = ["read","list"] }
path "yieldswarm/metadata/rpc/*"       { capabilities = ["read","list"] }

path "auth/token/lookup-self"   { capabilities = ["read"] }
path "auth/token/renew-self"    { capabilities = ["update"] }
path "auth/token/revoke-self"   { capabilities = ["update"] }
path "sys/capabilities-self"    { capabilities = ["update"] }
