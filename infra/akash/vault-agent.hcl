# ---------------------------------------------------------------------------
# Vault Agent config for the APN Akash runtime container.
#
# - AppRole auto-auth using the role-id / secret-id staged at /run/apn/vault.
# - Tokens cached on a tmpfs and rotated automatically. The agent
#   removes the secret-id from disk after the first successful login
#   (`remove_secret_id_file_after_reading`).
# - Templates render the platform secrets into a single dotenv file the
#   entrypoint sources before exec'ing the swarm process.
# - Templates are re-rendered when a secret version changes; an HUP is
#   sent to PID 1 so the agent process can react if needed.
# ---------------------------------------------------------------------------

pid_file = "/run/apn/vault/agent.pid"

vault {
  # Address is read from the VAULT_ADDR env var the entrypoint exports.
  retry {
    num_retries = 12
  }
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path                   = "/run/apn/vault/role-id"
      secret_id_file_path                 = "/run/apn/vault/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }

  sink "file" {
    config = {
      path = "/run/apn/vault/token"
      mode = 0600
    }
  }
}

cache {
  use_auto_auth_token = true
}

# No network listener: this agent renders files and goes back to sleep.
# Other in-pod processes that need a token read the sink file.

template {
  source      = "/etc/vault-agent/templates/apn.env.tmpl"
  destination = "/run/apn/secrets/apn.env"
  perms       = 0400
  command     = "/bin/sh -c 'echo \"[vault-agent] re-rendered apn.env at $(date -Iseconds)\" >&2'"
}

template_config {
  static_secret_render_interval = "5m"
  exit_on_retry_failure         = false
}
