#cloud-config
# Bootstraps a DigitalOcean Droplet to run AgentSwarm containers with Vault auth.

package_update: true
packages:
  - docker.io
  - jq
  - curl

runcmd:
  - systemctl enable --now docker
  - docker pull ${agent_image}
  - |
    docker run -d \
      --name agentswarm \
      --restart unless-stopped \
      -e VAULT_ADDR="${vault_addr}" \
      -e VAULT_ROLE_ID="${vault_approle_role_id}" \
      -e VAULT_SECRET_ID="${vault_approle_secret_id}" \
      -e AGENT_MODE="do-cron" \
      -p 8080:8080 \
      ${agent_image}
