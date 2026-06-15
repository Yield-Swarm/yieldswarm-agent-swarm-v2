# YieldSwarm AgentSwarm OS — Akash deployment image
# No secrets are baked in. All credentials injected at runtime via Vault AppRole.
FROM python:3.12-slim-bookworm

LABEL org.opencontainers.image.source="https://github.com/yieldswarm/agentswarm"
LABEL org.opencontainers.image.description="YieldSwarm AgentSwarm OS — Vault-injected secrets"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code (no secrets, no .env files)
COPY agents/ ./agents/
COPY mining/ ./mining/
COPY lib/ ./lib/

# Vault fetch + entrypoint scripts
COPY docker/vault-fetch.sh /usr/local/bin/vault-fetch.sh
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/vault-fetch.sh /usr/local/bin/entrypoint.sh

# Non-root user for runtime
RUN useradd --create-home --shell /bin/bash yieldswarm \
    && mkdir -p /run/yieldswarm \
    && chown yieldswarm:yieldswarm /run/yieldswarm /app

USER yieldswarm

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV AGENT_MODULE=agents.akash_optimizer

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD test -f /run/yieldswarm/secrets.env && pgrep -f python || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
