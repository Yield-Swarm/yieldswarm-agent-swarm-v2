pid_file = "/tmp/vault-agent.pid"
exit_after_auth = false

vault {
  address = "VAULT_ADDR_PLACEHOLDER"
  retry {
    num_retries = 5
  }
}

auto_auth {
  method {
    type = "approle"
    mount_path = "auth/approle"
    config = {
      role_id_file_path   = "/run/vault/role-id"
      secret_id_file_path = "/run/vault/secret-id"
      remove_secret_id_file_after_reading = true
    }
  }

  sink {
    type = "file"
    config = {
      path = "/tmp/vault-token"
      mode = 0600
    }
  }
}

template {
  source      = "/etc/vault/templates/secrets.env.tpl"
  destination = "/opt/yieldswarm/secrets.env"
  perms       = 0600
  command     = "touch /opt/yieldswarm/.secrets-ready"
}

template {
  source      = "/etc/vault/templates/rpc.env.tpl"
  destination = "/opt/yieldswarm/rpc.env"
  perms       = 0600
}
