# vault/policies/admin.hcl
# Full administrative access to Vault.
# Bind this only to trusted human operators — never to automated services.
#
# Apply:
#   vault policy write admin vault/policies/admin.hcl

path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Allow managing auth methods
path "auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Allow managing secret engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

# Allow managing policies
path "sys/policies/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Allow reading Vault health / status
path "sys/health" {
  capabilities = ["read", "sudo"]
}

path "sys/seal" {
  capabilities = ["sudo"]
}

path "sys/unseal" {
  capabilities = ["sudo"]
}

path "sys/step-down" {
  capabilities = ["sudo"]
}
