# Policy: agentswarm-admin
# Full read/write access to all AgentSwarm secrets.
# Assign to: operations engineers, on-call SREs.
# Never assign to automated workloads.

# All secrets under the agentswarm namespace
path "secret/data/agentswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/agentswarm/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Destroy and undelete specific secret versions
path "secret/destroy/agentswarm/*" {
  capabilities = ["update"]
}

path "secret/undelete/agentswarm/*" {
  capabilities = ["update"]
}

# Soft-delete specific secret versions
path "secret/delete/agentswarm/*" {
  capabilities = ["update"]
}

# AppRole management — create/rotate roles for automated actors
path "auth/approle/role/terraform" {
  capabilities = ["create", "read", "update", "delete"]
}

path "auth/approle/role/akash-runtime" {
  capabilities = ["create", "read", "update", "delete"]
}

path "auth/approle/role/ci-deploy" {
  capabilities = ["create", "read", "update", "delete"]
}

# Generate response-wrapped secret IDs for Akash deployments
path "auth/approle/role/akash-runtime/secret-id" {
  capabilities = ["update"]
}

path "auth/approle/role/terraform/secret-id" {
  capabilities = ["update"]
}

path "auth/approle/role/ci-deploy/secret-id" {
  capabilities = ["update"]
}

# Read role IDs (needed to share with deployment configs)
path "auth/approle/role/+/role-id" {
  capabilities = ["read"]
}

# Audit log inspection
path "sys/audit" {
  capabilities = ["read", "sudo"]
}

# Token self-renewal and lookup
path "auth/token/renew-self" {
  capabilities = ["update"]
}

path "auth/token/lookup-self" {
  capabilities = ["read"]
}
