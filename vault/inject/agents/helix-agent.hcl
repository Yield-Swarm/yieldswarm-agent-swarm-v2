pid_file = "/tmp/vault-agent-helix.pid"

vault {
  address = "{{ env "VAULT_ADDR" }}"
}

auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "/run/secrets/vault-role-id"
      secret_id_file_path = "/run/secrets/vault-secret-id"
    }
  }
}

template {
  source      = "/vault/inject/templates/vastai.env.ctmpl"
  destination = "/run/secrets/agent.env"
  perms       = 0600
}
