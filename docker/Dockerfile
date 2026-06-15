# docker/Dockerfile
# YieldSwarm AgentSwarm OS v2 — Production Container Image
#
# Build:
#   docker build -t yieldswarm/agent-swarm:latest -f docker/Dockerfile .
#
# Run (secrets injected at runtime from Vault — never hardcode):
#   docker run \
#     -e VAULT_ADDR="https://vault.yieldswarm.io:8200" \
#     -e VAULT_ROLE_ID="<role-id>" \
#     -e VAULT_SECRET_ID="<secret-id>" \
#     yieldswarm/agent-swarm:latest
#
# Multi-stage build: builder installs deps, final image is minimal.

# ── Stage 1: builder ───────────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Install build deps
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      curl \
    && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime ───────────────────────────────────────────────────────
FROM python:3.12-slim AS runtime

LABEL org.opencontainers.image.title="YieldSwarm AgentSwarm OS v2"
LABEL org.opencontainers.image.description="DePIN AI agent swarm with Vault-based secret injection"
LABEL org.opencontainers.image.source="https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2"
LABEL org.opencontainers.image.licenses="UNLICENSED"

# Runtime system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      jq \
      ca-certificates \
      tini \
    && rm -rf /var/lib/apt/lists/*

# Install Vault CLI (used by entrypoint.sh for clean token revocation)
ARG VAULT_VERSION=1.17.2
RUN ARCH=$(dpkg --print-architecture) \
 && curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${ARCH}.zip" \
      -o /tmp/vault.zip \
 && apt-get install -y --no-install-recommends unzip \
 && unzip /tmp/vault.zip -d /usr/local/bin/ \
 && rm /tmp/vault.zip \
 && chmod +x /usr/local/bin/vault \
 && apt-get remove -y unzip && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from builder
COPY --from=builder /install /usr/local

# Create non-root user
RUN groupadd -r agentswarm && useradd -r -g agentswarm -d /app -s /sbin/nologin agentswarm

WORKDIR /app

# Copy application source
COPY agents/    ./agents/
COPY mining/    ./mining/
COPY akash/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
 && chown -R agentswarm:agentswarm /app /entrypoint.sh

# Expose agent API port
EXPOSE 8080

# Expose Prometheus metrics port (scraped internally)
EXPOSE 9090

# Health check — expects the application to expose /health
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD curl -sf http://localhost:8080/health || exit 1

# Switch to non-root user
USER agentswarm

# Use tini as PID 1 for proper signal handling, then run entrypoint
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Default command (overridable via `docker run ... <cmd>`)
CMD []
