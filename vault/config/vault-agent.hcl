# ============================================================
# HashiCorp Vault Agent — Akash Container Configuration
# YieldSwarm AgentSwarm OS v2.0
#
# Pattern: Vault Agent runs as a supervised process inside
#          the container (via entrypoint.sh). It authenticates
#          via AppRole, maintains a renewable token, and
#          renders secrets to /vault/rendered/agent.env on
#          each rotation. The main agent process sources that
#          file on startup and on SIGHUP.
#
# Required env vars at container launch:
#   VAULT_ADDR         - https://vault.yieldswarm.internal:8200
#   VAULT_SKIP_VERIFY  - false (always verify TLS in prod)
# ============================================================

pid_file = "/tmp/vault-agent.pid"

# ── Vault server connection ──────────────────────────────────
vault {
  address = "VAULT_ADDR_PLACEHOLDER"   # replaced by entrypoint.sh

  # Retry on transient errors (network blips, leader election)
  retry {
    num_retries = 5
    backoff     = "250ms"
    max_backoff = "30s"
  }
}

# ── Auto-auth via AppRole ────────────────────────────────────
# entrypoint.sh writes VAULT_ROLE_ID and VAULT_SECRET_ID to
# these files before starting the agent process.
auto_auth {
  method "approle" {
    mount_path = "auth/approle"

    config = {
      role_id_file_path                   = "/vault/approle/role-id"
      secret_id_file_path                 = "/vault/approle/secret-id"
      remove_secret_id_file_after_reading = false  # keep for token renewal
    }
  }

  # Cache the renewable token to this file; other processes can
  # read it if they need direct Vault API access.
  sink "file" {
    config = {
      path = "/vault/approle/token"
      mode = "0640"
    }
  }
}

# ── Secret caching ──────────────────────────────────────────
# Local cache avoids hammering Vault on every secret read.
# Useful when many agents share the same sidecar.
cache {
  use_auto_auth_token = true
}

# ── Secret template rendering ────────────────────────────────
# agent.env is sourced by the main process at startup.
# Any secret rotation triggers a re-render followed by the
# command that signals the workload to pick up new values.
template {
  source      = "/vault/templates/agent-secrets.ctmpl"
  destination = "/vault/rendered/agent.env"
  perms       = "0640"
  error_on_missing_key = true

  # Reload the main process when secrets rotate
  # (Replace with the correct signal/command for your workload)
  exec {
    command = ["/bin/sh", "-c", "kill -HUP $(cat /tmp/agent.pid) 2>/dev/null || true"]
    timeout = "30s"
  }
}
