# Vault Agent configuration for Akash sidecar deployments.
# Alternative to entrypoint.sh curl-based injection — use when running vault-agent as a sidecar.
#
# Mount this file at /vault/config/agent.hcl
# Provide role-id and secret-id via Akash SDL env vars at deploy time.

pid_file = "/tmp/vault-agent.pid"

vault {
  retry {
    num_retries = 5
  }
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path   = "/vault/config/role-id"
      secret_id_file_path = "/vault/config/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }

  sink "file" {
    config = {
      path = "/run/secrets/vault-token"
      mode = 0600
    }
  }
}

template {
  source      = "/vault/templates/app.env.tpl"
  destination = "/run/secrets/app.env"
  perms       = 0600
  command     = "pkill -HUP -f 'akash-optimizer' || true"
}

template_config {
  static_secret_render_interval = "5m"
  exit_on_retry_failure         = true
}
