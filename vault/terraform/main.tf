# vault/terraform/main.tf
# Manages Vault configuration as code:
#   - KV v2 secrets engine
#   - AppRole auth method
#   - All policies
#
# This is the "Vault-admin" Terraform root — it runs once to bootstrap
# Vault itself. The infrastructure Terraform in /terraform/ reads from
# the secrets that operators populate afterwards.

# ---------------------------------------------------------------------------
# KV v2 Secrets Engine
# ---------------------------------------------------------------------------
resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "YieldSwarm AgentSwarm OS — KV v2 secrets engine"
}

# ---------------------------------------------------------------------------
# AppRole Auth Method
# ---------------------------------------------------------------------------
resource "vault_auth_backend" "approle" {
  type        = "approle"
  description = "AppRole auth for automated workloads (Terraform, Akash agents)"
}

# ---------------------------------------------------------------------------
# Policies
# ---------------------------------------------------------------------------
resource "vault_policy" "admin" {
  name   = "admin"
  policy = file("${path.module}/../policies/admin.hcl")
}

resource "vault_policy" "terraform" {
  name   = "terraform"
  policy = file("${path.module}/../policies/terraform.hcl")
}

resource "vault_policy" "akash_agent" {
  name   = "akash-agent"
  policy = file("${path.module}/../policies/akash-agent.hcl")
}
