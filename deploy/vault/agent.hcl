pid_file = "/tmp/vault-agent.pid"

vault {
  address = "https://vault.yieldswarm.crypto"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/vault/role-id"
      secret_id_file_path = "/vault/secret-id"
    }
  }

  sink "file" {
    config = {
      path = "/tmp/vault-token"
    }
  }
}

template {
  source      = "/vault/templates/api.env.tpl"
  destination = "/run/secrets/api.env"
  perms       = 0600
}

template {
  source      = "/vault/templates/payments.env.tpl"
  destination = "/run/secrets/payments.env"
  perms       = 0600
}

template {
  source      = "/vault/templates/kairo.env.tpl"
  destination = "/run/secrets/kairo.env"
  perms       = 0600
}
