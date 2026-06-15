#cloud-config
# =============================================================================
# Cloud-init: Bootstrap Vault Agent on a VM (Vultr / DigitalOcean)
# YieldSwarm AgentSwarm OS v2.0
#
# Rendered by Terraform templatefile(); values are substituted at apply time.
# The resulting cloud-init YAML never touches disk in the repo — only in the
# provider's metadata API.
# =============================================================================

packages:
  - curl
  - unzip
  - jq

write_files:
  - path: /etc/vault-agent/config.hcl
    permissions: "0640"
    content: |
      vault {
        address = "${vault_addr}"
        retry   { num_retries = 5 }
      }

      auto_auth {
        method "approle" {
          mount_path = "auth/approle"
          config = {
            role_id_file_path                   = "/etc/vault-agent/role-id"
            secret_id_file_path                 = "/etc/vault-agent/secret-id"
            remove_secret_id_file_after_reading = true
          }
        }
        sink "file" {
          config = { path = "/etc/vault-agent/.token", mode = 0640 }
        }
      }

      template_config {
        static_secret_render_interval = "5m"
        exit_on_retry_failure         = true
      }

      template {
        source      = "/etc/vault-agent/agent.env.tmpl"
        destination = "/run/vault-secrets/agent.env"
        perms       = 0640
      }

  - path: /etc/vault-agent/role-id
    permissions: "0640"
    content: "${vault_role_id}"

  - path: /etc/vault-agent/secret-id
    permissions: "0640"
    content: "${vault_secret_id}"

  - path: /etc/systemd/system/vault-agent.service
    permissions: "0644"
    content: |
      [Unit]
      Description=Vault Agent
      After=network.target

      [Service]
      Type=simple
      ExecStart=/usr/local/bin/vault agent -config=/etc/vault-agent/config.hcl
      Restart=on-failure
      RestartSec=5
      User=vault-agent
      Group=vault-agent

      [Install]
      WantedBy=multi-user.target

  - path: /etc/systemd/system/agentswarm.service
    permissions: "0644"
    content: |
      [Unit]
      Description=YieldSwarm AgentSwarm
      After=vault-agent.service
      Requires=vault-agent.service

      [Service]
      Type=simple
      EnvironmentFile=/run/vault-secrets/agent.env
      ExecStart=/opt/agentswarm/run.sh
      Restart=on-failure
      RestartSec=10

      [Install]
      WantedBy=multi-user.target

runcmd:
  # Install Vault binary
  - |
    VAULT_VERSION=1.17.1
    curl -fsSL "https://releases.hashicorp.com/vault/$${VAULT_VERSION}/vault_$${VAULT_VERSION}_linux_amd64.zip" \
      -o /tmp/vault.zip
    unzip -o /tmp/vault.zip -d /usr/local/bin/
    chmod 755 /usr/local/bin/vault
    rm /tmp/vault.zip

  # Create vault-agent user
  - useradd --system --no-create-home --shell /bin/false vault-agent || true
  - chown -R vault-agent:vault-agent /etc/vault-agent
  - mkdir -p /run/vault-secrets
  - chown vault-agent:vault-agent /run/vault-secrets

  # Set VAULT_ENVIRONMENT in agent template path via environment variable
  - echo "VAULT_ENVIRONMENT=${vault_environment}" >> /etc/environment

  # Enable and start services
  - systemctl daemon-reload
  - systemctl enable vault-agent agentswarm
  - systemctl start vault-agent
