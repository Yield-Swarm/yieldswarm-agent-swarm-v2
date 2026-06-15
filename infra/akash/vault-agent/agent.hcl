# =============================================================================
# Vault Agent configuration for AgentSwarm runtime containers.
#
# Behaviour:
#   * Auto-auth via AppRole (role_id + secret_id are written to disk by
#     docker-entrypoint.sh BEFORE this agent starts).
#   * The acquired token is sinked to disk for the app process to use, AND
#     used by the agent itself to render env-file templates.
#   * Cache is enabled so the app's vault SDK can short-circuit reads.
#   * Auto-auth's `remove_secret_id_file_after_reading` is TRUE -- the
#     secret_id is single-use and burned after first login.
# =============================================================================

pid_file = "/var/run/vault-agent/agent.pid"

# `vault.address` is intentionally omitted - Vault Agent picks it up from the
# VAULT_ADDR environment variable injected by the Akash deployment manifest.
# This keeps the image / config portable across environments.
vault {
  retry {
    num_retries = 10
  }
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path                   = "/var/run/vault-agent/role-id"
      secret_id_file_path                 = "/var/run/vault-agent/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }

  sink "file" {
    config = {
      path = "/var/run/vault-agent/token"
      mode = 0400
    }
  }
}

cache {
  use_auto_auth_token = true
}

listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true
}

# -----------------------------------------------------------------------------
# Template: render every runtime secret into a single env file the app reads
# at startup. Vault Agent re-renders this file whenever any source secret
# version changes and (optionally) signals the app via the `command` hook.
# -----------------------------------------------------------------------------
template {
  source      = "/etc/vault-agent/templates/runtime.env.ctmpl"
  destination = "/etc/agentswarm/secrets/runtime.env"
  perms       = "0400"
  command     = "/usr/bin/pkill -SIGHUP -f 'python -m agentswarm' || true"
  error_on_missing_key = true
}

# -----------------------------------------------------------------------------
# Optional sidecar template: RPC endpoints in JSON for the RPC failover client.
# -----------------------------------------------------------------------------
template {
  source      = "/etc/vault-agent/templates/rpc.json.ctmpl"
  destination = "/etc/agentswarm/secrets/rpc.json"
  perms       = "0400"
  error_on_missing_key = true
}

# -----------------------------------------------------------------------------
# Telemetry
# -----------------------------------------------------------------------------
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname          = true
}
