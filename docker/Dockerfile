# =============================================================================
# YieldSwarm AgentSwarm OS v2.0
# Multi-stage Dockerfile — Akash / RunPod / Vultr / DigitalOcean
#
# Stage 1 (vault-bin)  : downloads the pinned Vault binary
# Stage 2 (runtime)    : minimal Python runtime + Vault Agent + app code
#
# Secrets are NEVER baked in. The container starts with only:
#   VAULT_ADDR, VAULT_ROLE_ID, VAULT_SECRET_ID, VAULT_ENVIRONMENT
# Vault Agent fetches everything else at runtime and passes it to the app
# via the exec stanza (no env files written to disk that persist after boot).
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: fetch the Vault binary (avoids curl in the final image)
# ---------------------------------------------------------------------------
FROM alpine:3.19 AS vault-bin

ARG VAULT_VERSION=1.17.1
ARG VAULT_SHA256=7f8b7afb6a012e9f2c625fb5c5bb2bf58b64dad1a4e7db1b3a8e18d0de35f09a

RUN apk add --no-cache curl unzip && \
    curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
         -o /tmp/vault.zip && \
    echo "${VAULT_SHA256}  /tmp/vault.zip" | sha256sum -c - && \
    unzip /tmp/vault.zip -d /usr/local/bin/ && \
    chmod 755 /usr/local/bin/vault && \
    rm /tmp/vault.zip

# ---------------------------------------------------------------------------
# Stage 2: runtime image
# ---------------------------------------------------------------------------
FROM python:3.11-slim-bookworm AS runtime

LABEL org.opencontainers.image.title="YieldSwarm AgentSwarm OS"
LABEL org.opencontainers.image.description="10,080 AI agents — secrets injected at runtime via Vault Agent"
LABEL org.opencontainers.image.version="2.0"

# --- Vault binary from stage 1 ---
COPY --from=vault-bin /usr/local/bin/vault /usr/local/bin/vault

# --- Create non-root user for the application ---
RUN groupadd --gid 1001 agentswarm && \
    useradd  --uid 1001 --gid agentswarm --no-create-home --shell /bin/false agentswarm

# --- Create required directories with correct permissions ---
RUN mkdir -p \
      /vault/config \
      /vault/auth \
      /vault/secrets \
      /vault/templates \
      /vault/tls \
      /app && \
    chown -R agentswarm:agentswarm /vault /app

# --- Install Python dependencies ---
# Copy requirements first so Docker can cache this layer independently.
COPY --chown=agentswarm:agentswarm docker/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r /app/requirements.txt

# --- Vault Agent configuration (no secrets here) ---
COPY --chown=agentswarm:agentswarm vault/config/vault-agent.hcl   /vault/config/agent.hcl
COPY --chown=agentswarm:agentswarm vault/templates/agent.env.tmpl /vault/templates/agent.env.tmpl

# --- Application code ---
COPY --chown=agentswarm:agentswarm agents/  /app/agents/
COPY --chown=agentswarm:agentswarm mining/  /app/mining/

# --- Entrypoint scripts ---
COPY --chown=agentswarm:agentswarm docker/entrypoint.sh        /app/entrypoint.sh
COPY --chown=agentswarm:agentswarm docker/entrypoint-inner.sh  /app/entrypoint-inner.sh
RUN chmod 755 /app/entrypoint.sh /app/entrypoint-inner.sh

# Drop to non-root
USER agentswarm
WORKDIR /app

# Expose agent HTTP port (health checks, Prometheus metrics)
EXPOSE 8080

# Vault Agent is PID 1; it renders secrets and then execs the inner entrypoint.
ENTRYPOINT ["/app/entrypoint.sh"]
