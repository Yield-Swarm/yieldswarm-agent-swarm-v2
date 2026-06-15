# ---------------------------------------------------------------------------
# terraform/approle.tf
# AppRole credential variables — injected at runtime, never hardcoded.
#
# The role_id is non-sensitive (it's just an identifier).
# The secret_id MUST be a response-wrapped single-use token from Vault.
# ---------------------------------------------------------------------------

variable "vault_approle_role_id" {
  description = <<-EOT
    Vault AppRole role_id for the akash-runtime role.
    Retrieve with: vault read auth/approle/role/akash-runtime/role-id
    This value is safe to store in VCS or CI variables.
  EOT
  type        = string
}

variable "vault_approle_secret_id" {
  description = <<-EOT
    Vault AppRole secret_id (response-wrapped) for the akash-runtime role.
    Generate with: vault write -wrap-ttl=10m -f auth/approle/role/akash-runtime/secret-id
    This value is sensitive — provide via TF_VAR_vault_approle_secret_id env var
    or a secrets manager. Never store in terraform.tfvars.
  EOT
  type      = string
  sensitive = true
}
