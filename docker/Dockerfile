# ============================================================
# YieldSwarm AgentSwarm OS — Container Image
#
# Build: docker build -t yieldswarm/agentswarm:latest docker/
# Push:  docker push yieldswarm/agentswarm:latest
#
# Multi-stage build:
#   stage 1 (deps)    — install Python dependencies
#   stage 2 (runtime) — minimal production image
#
# Secrets are NEVER baked into the image. The entrypoint.sh
# fetches all secrets from Vault at container startup.
# ============================================================

# ── Stage 1: dependency builder ───────────────────────────────
FROM python:3.11-slim AS deps

WORKDIR /build

COPY requirements.txt ./

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: production runtime ──────────────────────────────
FROM python:3.11-slim AS runtime

LABEL org.opencontainers.image.title="YieldSwarm AgentSwarm OS"
LABEL org.opencontainers.image.description="AI agent swarm runtime with Vault-based secret injection"
LABEL org.opencontainers.image.source="https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2"

# ── System packages ───────────────────────────────────────────
# curl + jq: required by entrypoint.sh for Vault API calls
# vault: optional — provides token renewal via Vault Agent
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
      jq \
      ca-certificates \
      unzip \
    && VAULT_VERSION=$(curl -sS https://releases.hashicorp.com/vault/index.json \
         | jq -r '[.versions[].version] | map(select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))) | sort_by(split(".") | map(tonumber)) | last') \
    && curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
         -o /tmp/vault.zip \
    && unzip -d /usr/local/bin /tmp/vault.zip \
    && rm /tmp/vault.zip \
    && chmod +x /usr/local/bin/vault \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Create runtime user (never run as root) ───────────────────
RUN groupadd --gid 10001 agentswarm \
    && useradd  --uid 10001 --gid agentswarm \
                --shell /bin/bash \
                --create-home agentswarm

# ── Python dependencies from builder stage ────────────────────
COPY --from=deps /install /usr/local

# ── Application code ──────────────────────────────────────────
WORKDIR /app
COPY agents/     ./agents/
COPY mining/     ./mining/

# ── Vault runtime directories ─────────────────────────────────
RUN install -m 0700 -o agentswarm -g agentswarm -d \
      /vault/approle \
      /vault/rendered \
      /vault/templates \
      /vault/config

# ── Vault Agent template and config ──────────────────────────
COPY vault/templates/agent-secrets.ctmpl /vault/templates/
COPY vault/config/vault-agent.hcl        /vault/config/

# ── Entrypoint ────────────────────────────────────────────────
COPY akash/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

# ── Workspace for persistent data ────────────────────────────
RUN install -m 0755 -o agentswarm -g agentswarm -d /workspace/data

# ── Drop privileges ───────────────────────────────────────────
USER agentswarm
WORKDIR /app

# ── Health check ──────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD curl -sf http://localhost:8080/healthz || exit 1

# ── Exposed ports ────────────────────────────────────────────
EXPOSE 8080   # HTTP health / API
EXPOSE 9090   # Prometheus metrics

# ── Default startup ───────────────────────────────────────────
# Overridden by Akash SDL command[] or docker run arguments.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["python", "/app/agents/akash-optimizer.py"]
