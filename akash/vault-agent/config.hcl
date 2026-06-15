# akash/vault-agent/config.hcl
#
# Vault Agent runtime config for the YieldSwarm Akash workload.
#
# Auto-auth via AppRole: vault-agent reads role_id and secret_id from tmpfs
# files written by entrypoint.sh. It does NOT need a long-lived token, and it
# will never write the token to disk (sink "file" is intentionally absent).
#
# Templates render /run/secrets/env atomically every time any underlying KV
# version changes or any lease comes up for renewal.

pid_file = "/var/run/vault/agent.pid"

vault {
  # `address` intentionally omitted — Vault Agent reads VAULT_ADDR from the
  # process environment, which is set by the Akash SDL. Pinning it here would
  # require a build per environment.

  retry {
    num_retries = 10
  }
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"
    config = {
      role_id_file_path                   = "/var/run/vault/role_id"
      secret_id_file_path                 = "/var/run/vault/secret_id"
      remove_secret_id_file_after_reading = true
    }
  }

  # No sink: we don't want the auth token persisted anywhere. Templates use
  # the in-memory token directly via the agent's internal API.
}

# Caching speeds up template re-renders and lease renewals.
cache {
  use_auto_auth_token = true
}

# Local listener is loopback-only; the app never talks to it (we use templates
# for env injection), but it's useful for debug exec into the container.
listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true
}

template {
  source      = "/etc/vault-agent/templates/env.ctmpl"
  destination = "/run/secrets/env"
  perms       = "0400"
  # Atomic write: agent writes to a temp file and renames into place.
  # The entrypoint sources this file once on startup; SIGHUP-aware apps
  # can resource on changes.
  command     = "sh -c 'kill -HUP 1 2>/dev/null || true'"
}
