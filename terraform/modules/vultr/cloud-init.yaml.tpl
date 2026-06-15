#cloud-config
# Bootstraps a Vultr VPS to run AgentSwarm containers authenticated with Vault.
# Vault credentials are injected here at Terraform plan time; they are never
# stored in the repository.

package_update: true
packages:
  - docker.io
  - jq
  - curl

runcmd:
  # Enable and start Docker
  - systemctl enable --now docker

  # Pull the agent image
  - docker pull ${agent_image}

  # Run the agent container — entrypoint.sh handles Vault auth internally
  - |
    docker run -d \
      --name agentswarm \
      --restart unless-stopped \
      -e VAULT_ADDR="${vault_addr}" \
      -e VAULT_ROLE_ID="${vault_approle_role_id}" \
      -e VAULT_SECRET_ID="${vault_approle_secret_id}" \
      -e AGENT_MODE="vultr-cron" \
      -p 8080:8080 \
      ${agent_image}
