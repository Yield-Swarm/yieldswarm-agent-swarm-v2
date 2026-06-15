FROM hashicorp/vault:1.17 AS vault
FROM python:3.12-slim-bookworm

LABEL org.opencontainers.image.title="YieldSwarm AgentSwarm OS"
LABEL org.opencontainers.image.description="Akash deployment with Vault runtime secret injection"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tini \
    && rm -rf /var/lib/apt/lists/*

COPY --from=vault /bin/vault /usr/local/bin/vault

WORKDIR /app

COPY lib/ /app/lib/
COPY agents/ /app/agents/
COPY akash/entrypoint.sh /entrypoint.sh
COPY akash/vault-agent.hcl /etc/vault/vault-agent.hcl
COPY akash/templates/ /etc/vault/templates/

RUN mkdir -p /opt/yieldswarm /run/vault \
    && chmod 700 /opt/yieldswarm /run/vault \
    && chmod +x /entrypoint.sh

ENV PYTHONUNBUFFERED=1 \
    YIELDSWARM_SECRETS_FILE=/opt/yieldswarm/secrets.env \
    VAULT_AGENT_CONFIG=/etc/vault/vault-agent.hcl

# Non-secret config only — credentials injected at runtime.
ENV LOG_LEVEL=INFO \
    AGENT_COUNT_TOTAL=10080 \
    AGENTS_PER_SHARD=84

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD test -f /opt/yieldswarm/.secrets-ready && python3 -c "from lib.secrets import validate_required; validate_required()"

ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD []
