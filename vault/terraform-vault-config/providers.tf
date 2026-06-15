# The Vault provider authenticates with VAULT_ADDR + VAULT_TOKEN from env.
# In CI we exchange a wrapped SecretID minted by the ci-bootstrap AppRole
# for a short-lived token, export it as VAULT_TOKEN, then run terraform.
provider "vault" {
  # Address may be overridden by VAULT_ADDR env var; CI sets it there.
  address = var.vault_address

  # Token always comes from VAULT_TOKEN env var; never hard-coded.

  # Limit blast radius - the token issued for `terraform apply` here is
  # capped to 1 hour and re-issued every run.
  max_lease_ttl_seconds = 3600

  # Skip child token creation to keep audit trail tied to ci identity.
  skip_child_token = true
}
