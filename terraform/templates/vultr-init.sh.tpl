#!/bin/bash
# Vultr cloud-init — installs Vault Agent; secrets injected at boot from AppRole.
set -euo pipefail

VAULT_ADDR="${vault_addr}"

curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/hashicorp.list
apt-get update && apt-get install -y vault

mkdir -p /etc/vault-agent /opt/yieldswarm
cat > /etc/vault-agent/agent.hcl <<'AGENT'
pid_file = "/tmp/vault-agent.pid"
exit_after_auth = false

vault {
  address = "VAULT_ADDR_PLACEHOLDER"
}

auto_auth {
  method {
    type = "approle"
    config = {
      role_id_file_path   = "/etc/vault-agent/role-id"
      secret_id_file_path = "/etc/vault-agent/secret-id"
    }
  }
  sink {
    type = "file"
    config = { path = "/tmp/vault-token" }
  }
}
AGENT

sed -i "s|VAULT_ADDR_PLACEHOLDER|${VAULT_ADDR}|g" /etc/vault-agent/agent.hcl
echo "Provision role-id and secret-id via secure channel before starting agent."
