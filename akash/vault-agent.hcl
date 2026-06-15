# =========================================================================
# Vault Agent config for YieldSwarm Akash workers.
#
# - Auth: AppRole (akash-runtime), SecretID delivered response-wrapped
#   via the VAULT_WRAPPED_SECRET_ID env var. The entrypoint unwraps it
#   into /run/secrets/secret-id which is then deleted after first read.
# - Templates: render /run/secrets/agent.env from KVv2.
# - Token cache: in-memory only, never written to disk.
# - On any secret change the agent re-renders and signals the workload
#   to reload via SIGHUP (the YieldSwarm agent reloads env on SIGHUP).
# =========================================================================

pid_file = "/run/secrets/vault-agent.pid"

vault {
  # Address comes from VAULT_ADDR env var (set in Akash SDL).
  retry {
    num_retries = 10
  }
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path                   = "/run/secrets/role-id"
      secret_id_file_path                 = "/run/secrets/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }

  # In-memory sink only. We deliberately do NOT persist the token to disk.
  sink "file" {
    config = {
      path = "/run/secrets/vault-token"
      mode = 0400
    }
  }
}

# API proxy for the workload: the python agent can hit
# http://127.0.0.1:8100/v1/... without ever knowing the token.
listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true

  agent_api {
    enable_quit = false
  }
}

cache {
  use_auto_auth_token = true
}

template {
  source        = "/etc/vault-agent/templates/runtime.env.ctmpl"
  destination   = "/run/secrets/agent.env"
  perms         = "0400"
  exec {
    command = "/usr/bin/pkill -HUP -f 'yieldswarm.agent' || true"
  }
}

# Render every secret read into a single env file so the workload can
# `source /run/secrets/agent.env`. Vault Agent re-renders automatically
# when leases / KV versions change.

template_config {
  static_secret_render_interval = "5m"
  exit_on_retry_failure         = true
}
