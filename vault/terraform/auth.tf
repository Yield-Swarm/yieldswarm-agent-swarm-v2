# vault/terraform/auth.tf
# AppRole roles for Terraform CI/CD and Akash runtime agents.

# ---------------------------------------------------------------------------
# Terraform AppRole Role
# ---------------------------------------------------------------------------
resource "vault_approle_auth_backend_role" "terraform" {
  backend   = vault_auth_backend.approle.path
  role_name = "terraform"

  token_policies    = [vault_policy.terraform.name]
  token_ttl         = var.terraform_token_ttl
  token_max_ttl     = var.terraform_token_max_ttl
  token_num_uses    = 0
  secret_id_ttl     = "0"   # Secret IDs never expire — rotated manually
  bind_secret_id    = true
}

# ---------------------------------------------------------------------------
# Akash Agent AppRole Role
# ---------------------------------------------------------------------------
resource "vault_approle_auth_backend_role" "akash_agent" {
  backend   = vault_auth_backend.approle.path
  role_name = "akash-agent"

  token_policies    = [vault_policy.akash_agent.name]
  token_ttl         = var.akash_agent_token_ttl
  token_max_ttl     = var.akash_agent_token_max_ttl
  token_num_uses    = 0
  secret_id_ttl     = var.akash_agent_secret_id_ttl
  bind_secret_id    = true
}

# ---------------------------------------------------------------------------
# Outputs — role IDs are non-sensitive and safe to output
# ---------------------------------------------------------------------------
output "terraform_role_id" {
  description = "Role ID for the Terraform AppRole. Store in CI/CD as VAULT_ROLE_ID."
  value       = vault_approle_auth_backend_role.terraform.role_id
}

output "akash_agent_role_id" {
  description = "Role ID for the Akash Agent AppRole. Embed in Akash SDL env block."
  value       = vault_approle_auth_backend_role.akash_agent.role_id
}
