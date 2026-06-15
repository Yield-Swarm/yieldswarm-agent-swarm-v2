# ---------------------------------------------------------------------------
# akash/Dockerfile
# YieldSwarm AgentSwarm OS — production container image.
#
# Secrets are NEVER baked into this image.
# At startup, entrypoint.sh authenticates with Vault using AppRole
# and injects all secrets as environment variables before exec-ing the agent.
# ---------------------------------------------------------------------------

FROM python:3.11-slim AS base

# ---------------------------------------------------------------------------
# Build-time arguments — change Vault version via --build-arg
# ---------------------------------------------------------------------------
ARG VAULT_VERSION=1.17.5
ARG TARGETARCH=amd64

# ---------------------------------------------------------------------------
# System dependencies
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        unzip \
        jq \
        ca-certificates \
        tini \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Install Vault CLI (used by entrypoint.sh for secret injection)
# ---------------------------------------------------------------------------
RUN ARCH="${TARGETARCH}" && \
    curl -fsSL \
      "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH}.zip" \
      -o /tmp/vault.zip && \
    unzip -q /tmp/vault.zip -d /usr/local/bin/ && \
    rm /tmp/vault.zip && \
    chmod 755 /usr/local/bin/vault && \
    vault version

# ---------------------------------------------------------------------------
# Application layer
# ---------------------------------------------------------------------------
WORKDIR /app

# Copy agent source files
COPY agents/           ./agents/
COPY mining/           ./mining/

# If you add a requirements.txt, uncomment:
# COPY requirements.txt ./
# RUN pip install --no-cache-dir -r requirements.txt

# Copy the entrypoint (secret injection + exec)
COPY akash/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ---------------------------------------------------------------------------
# Security hardening — run as a non-root user
# ---------------------------------------------------------------------------
RUN groupadd --gid 10001 agentswarm && \
    useradd --uid 10001 --gid 10001 --no-create-home --shell /sbin/nologin agentswarm

# /vault/data is the default Vault agent cache dir if ever used
RUN mkdir -p /vault/cache && chown agentswarm:agentswarm /vault/cache

USER agentswarm

# ---------------------------------------------------------------------------
# Runtime
# ---------------------------------------------------------------------------
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    VAULT_SKIP_VERIFY=false

# tini handles signal forwarding and zombie reaping
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
CMD ["python", "agents/akash-optimizer.py"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -sf http://localhost:8080/healthz || exit 1
