#cloud-config
# Vultr coordinator cloud-init.
# Installs Docker, pulls the agent image, and starts the container.
# VAULT_ROLE_ID and VAULT_SECRET_ID are the only secrets present here.
# All other secrets are fetched by entrypoint.sh from Vault at startup.

package_update: true
package_upgrade: true

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
  - jq

runcmd:
  # Install Docker
  - curl -fsSL https://get.docker.com | sh
  - systemctl enable docker
  - systemctl start docker

  # Pull agent image
  - docker pull ${agent_image}

  # Run container with only Vault AppRole credentials as env vars.
  # entrypoint.sh inside the container fetches all secrets from Vault.
  - |
    docker run -d \
      --name yieldswarm-agent \
      --restart unless-stopped \
      -e VAULT_ADDR="${vault_addr}" \
      -e VAULT_ROLE_ID="${vault_role_id}" \
      -e VAULT_SECRET_ID="${vault_secret_id}" \
      -e LOG_LEVEL="${log_level}" \
      -p 8080:8080 \
      ${agent_image}

final_message: "YieldSwarm agent container started. Check: docker logs yieldswarm-agent"
