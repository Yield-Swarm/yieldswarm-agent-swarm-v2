# =========================================================================
# Secrets engines and audit devices.
# =========================================================================

resource "vault_mount" "yieldswarm" {
  path        = var.kv_mount_path
  type        = "kv"
  options     = { version = "2" }
  description = "YieldSwarm application secrets (KVv2)."
}

resource "vault_mount" "transit" {
  path        = var.transit_mount_path
  type        = "transit"
  description = "Envelope-encryption keys for at-rest secrets in apps and Terraform state."
}

resource "vault_transit_secret_backend_key" "named" {
  for_each         = toset(var.transit_keys)
  backend          = vault_mount.transit.path
  name             = each.value
  type             = "aes256-gcm96"
  deletion_allowed = false
  exportable       = false
}

resource "vault_audit" "file" {
  type = "file"
  options = {
    file_path = var.audit_file_path
  }
}
