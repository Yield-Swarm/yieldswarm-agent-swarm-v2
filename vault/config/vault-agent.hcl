# =============================================================================
# Vault Agent Configuration — Akash / Docker runtime
# YieldSwarm AgentSwarm OS v2.0
#
# This file is baked into the Docker image at /vault/config/agent.hcl.
# No secrets are stored here; all sensitive values come from Vault.
#
# Runtime environment variables the container must receive:
#   VAULT_ADDR        — https://vault.yieldswarm.internal:8200
#   VAULT_CACERT      — path to CA cert (or set VAULT_SKIP_VERIFY=true for dev)
#   VAULT_ROLE_ID     — AppRole role_id (non-sensitive, acts like a username)
#   VAULT_SECRET_ID   — AppRole secret_id (sensitive, rotate after each deploy)
#   VAULT_ENVIRONMENT — e.g. "production" or "staging" (used in secret paths)
#
# The entrypoint.sh writes VAULT_ROLE_ID → /vault/auth/role-id and
# VAULT_SECRET_ID → /vault/auth/secret-id before starting this agent.
# =============================================================================

vault {
  address = "VAULT_ADDR"   # overridden by VAULT_ADDR environment variable

  retry {
    num_retries = 5
  }
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"

    config = {
      role_id_file_path                   = "/vault/auth/role-id"
      secret_id_file_path                 = "/vault/auth/secret-id"
      # Consume and delete the secret_id immediately after first use so it
      # cannot be re-read from the container filesystem.
      remove_secret_id_file_after_reading = true
    }
  }

  # Cache the Vault token on disk so templates can be re-rendered on renewal
  # without re-authenticating.
  sink "file" {
    config = {
      path = "/vault/auth/.token"
      mode = 0640
    }
  }
}

# Keep secrets in memory and refresh every 5 minutes (or on lease expiry).
cache {
  use_auto_auth_token = true
}

# Template rendering options
template_config {
  static_secret_render_interval = "5m"
  exit_on_retry_failure         = true
  max_connections_per_host      = 10
}

# ---------------------------------------------------------------------------
# Secret template: renders all required env vars to /vault/secrets/agent.env
# The exec stanza starts the application after all templates are rendered.
# ---------------------------------------------------------------------------
template {
  source               = "/vault/templates/agent.env.tmpl"
  destination          = "/vault/secrets/agent.env"
  perms                = 0640
  error_on_missing_key = true
  # On secret rotation, send SIGHUP to the main process so it can reload.
  command              = "kill -HUP $(cat /app/main.pid 2>/dev/null) 2>/dev/null || true"
}

# ---------------------------------------------------------------------------
# Process supervisor: Vault Agent launches the app after secrets are ready.
# The application reads /vault/secrets/agent.env at startup.
# ---------------------------------------------------------------------------
exec {
  command                   = ["/app/entrypoint-inner.sh"]
  restart_stop_signal       = "SIGTERM"
  restart_on_secret_changes = "never"    # set to "always" for hot reload
  env {
    pristine = false
  }
}
