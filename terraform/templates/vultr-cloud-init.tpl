#cloud-config
# Vultr cloud-init — installs Vault CLI and starts agent with runtime secret injection.
package_update: true
packages:
  - curl
  - jq
  - docker.io

write_files:
  - path: /etc/systemd/system/yieldswarm-agent.service
    permissions: "0644"
    content: |
      [Unit]
      Description=YieldSwarm Agent
      After=docker.service
      Requires=docker.service

      [Service]
      Environment=VAULT_ADDR=${vault_addr}
      Environment=VAULT_ROLE_ID=${vault_role_id}
      Environment=VAULT_SECRET_ID=${vault_secret_id}
      Environment=SOLANA_RPC_URL=${solana_rpc_url}
      ExecStartPre=/usr/local/bin/vault-fetch.sh
      ExecStart=/usr/bin/docker run --rm \
        --env-file /run/yieldswarm/secrets.env \
        ghcr.io/yieldswarm/agentswarm:latest
      Restart=on-failure
      RestartSec=30

  - path: /usr/local/bin/vault-fetch.sh
    permissions: "0755"
    content: |
      #!/bin/bash
      set -euo pipefail
      mkdir -p /run/yieldswarm
      TOKEN=$(curl -sf --request POST \
        --data "{\"role_id\":\"$VAULT_ROLE_ID\",\"secret_id\":\"$VAULT_SECRET_ID\"}" \
        "$VAULT_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')
      curl -sf -H "X-Vault-Token: $TOKEN" \
        "$VAULT_ADDR/v1/secret/data/yieldswarm/agents/shared" \
        | jq -r '.data.data | to_entries[] | "\(.key | ascii_upcase)=\(.value | @sh)"' \
        > /run/yieldswarm/secrets.env
      chmod 600 /run/yieldswarm/secrets.env

runcmd:
  - curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  - echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
  - apt-get update && apt-get install -y vault
  - systemctl enable docker
  - systemctl start docker
  - systemctl enable yieldswarm-agent
  - systemctl start yieldswarm-agent
