#cloud-config
# DigitalOcean Droplet cloud-init.
# Mirrors the Vultr template — only Vault AppRole credentials are present.
# All agent secrets are fetched by entrypoint.sh at container startup.

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
  - curl -fsSL https://get.docker.com | sh
  - systemctl enable docker
  - systemctl start docker
  - docker pull ${agent_image}
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
