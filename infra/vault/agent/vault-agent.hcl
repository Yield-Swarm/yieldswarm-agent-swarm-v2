## Vault Agent config used inside the Akash container.
## - Authenticates via AppRole (role_id baked into image, secret_id supplied
##   response-wrapped at runtime).
## - Renders the rendered env file via `template`, then exits if `exit_after_auth`
##   is true (init-container mode); otherwise keeps renewing.

pid_file = "/run/vault-agent/agent.pid"

vault {
  address       = "{{ env \"VAULT_ADDR\" }}"
  tls_skip_verify = false
  ca_cert       = "/etc/ssl/certs/vault-ca.crt"
  retry { num_retries = 5 }
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path                   = "/run/vault-agent/role_id"
      secret_id_file_path                 = "/run/vault-agent/secret_id"
      remove_secret_id_file_after_reading = true
      secret_id_response_wrapping_path    = "auth/approle/role/akash-runtime/secret-id"
    }
  }

  sink "file" {
    config = {
      path = "/run/vault-agent/token"
      mode = 0o400
    }
  }
}

cache {
  use_auto_auth_token = true
}

# Render application secrets into a tmpfs env file consumed by entrypoint.sh
template {
  source      = "/etc/vault-agent/templates/app.env.ctmpl"
  destination = "/run/vault-agent/app.env"
  perms       = 0o400
  error_on_missing_key = true
  command     = "/bin/sh -c 'kill -HUP $(cat /run/vault-agent/app.pid 2>/dev/null) 2>/dev/null || true'"
}

# Optional listener so co-located processes can hit a local Vault proxy
# without re-authenticating.
listener "tcp" {
  address     = "127.0.0.1:8100"
  tls_disable = true
}

# Telemetry hook (Prometheus scrape on the cache listener)
telemetry {
  disable_hostname          = true
  prometheus_retention_time = "30s"
}
