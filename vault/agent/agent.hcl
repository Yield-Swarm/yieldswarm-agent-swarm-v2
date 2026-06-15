# Optional Vault Agent sidecar config for Akash / Kubernetes.
# Renders secrets to /vault/secrets/*.env without embedding values in the main container.
# Mount this file and run: vault agent -config=/vault/config/agent.hcl

vault {
  address = "https://vault.yieldswarm.internal:8200"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path   = "/vault/config/role-id"
      secret_id_file_path = "/vault/config/secret-id"
    }
  }

  sink "file" {
    config = {
      path = "/vault/token"
      mode = 0600
    }
  }
}

template {
  source      = "/vault/templates/app.env.tpl"
  destination = "/vault/secrets/app.env"
  perms       = 0600
  command     = "pkill -HUP -f akash-optimizer || true"
}
