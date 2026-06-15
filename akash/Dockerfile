FROM python:3.12-slim-bookworm

ARG VAULT_VERSION=1.17.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    jq \
    tini \
  && rm -rf /var/lib/apt/lists/*

# Vault CLI for AppRole login and KV reads at container start
RUN curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
    -o /tmp/vault.zip \
  && unzip /tmp/vault.zip -d /usr/local/bin \
  && rm /tmp/vault.zip \
  && chmod +x /usr/local/bin/vault

WORKDIR /app

COPY agents/ /app/agents/
COPY akash/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Runtime secrets are injected by entrypoint — nothing sensitive in the image
ENV PYTHONUNBUFFERED=1 \
    VAULT_KV_MOUNT=yieldswarm \
    VAULT_SKIP_VERIFY=false

ENTRYPOINT ["tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["python", "-u", "agents/akash-optimizer.py"]
