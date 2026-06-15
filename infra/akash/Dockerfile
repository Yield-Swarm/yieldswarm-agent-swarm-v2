# syntax=docker/dockerfile:1.7
# =============================================================================
# YieldSwarm AgentSwarm OS runtime image.
#
# Hard rules:
#   1. NO SECRETS BAKED IN. The image never contains an API key, wallet seed,
#      or RPC token. Every secret arrives at runtime via Vault Agent.
#   2. No COPY of .env, .env.example, .env.* into the image.
#   3. Vault Agent runs as PID 1 (via supervisord) and renders /etc/agentswarm/
#      env files BEFORE the main process is allowed to start.
#   4. Container runs as a dedicated unprivileged user (uid 10001).
# =============================================================================

ARG PYTHON_VERSION=3.12-slim-bookworm
ARG VAULT_VERSION=1.17.6

# -----------------------------------------------------------------------------
# Stage 1: pull the Vault binary (provides vault + vault-agent in one binary)
# -----------------------------------------------------------------------------
FROM hashicorp/vault:${VAULT_VERSION} AS vault-bin

# -----------------------------------------------------------------------------
# Stage 2: build Python deps in a wheel-only layer
# -----------------------------------------------------------------------------
FROM python:${PYTHON_VERSION} AS python-build

WORKDIR /build
COPY agentswarm/requirements.txt ./requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip wheel --wheel-dir=/build/wheels -r requirements.txt

# -----------------------------------------------------------------------------
# Stage 3: final runtime
# -----------------------------------------------------------------------------
FROM python:${PYTHON_VERSION} AS runtime

ARG VAULT_VERSION
LABEL org.opencontainers.image.title="yieldswarm-agentswarm-os" \
      org.opencontainers.image.source="https://github.com/Yield-Swarm/yieldswarm-agent-swarm-v2" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.vendor="YieldSwarm" \
      io.yieldswarm.vault-agent-version="${VAULT_VERSION}"

RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl jq tini supervisor; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd --gid 10001 agentswarm; \
    useradd  --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin agentswarm; \
    install -d -o agentswarm -g agentswarm -m 0750 \
      /etc/agentswarm /etc/agentswarm/secrets /var/log/agentswarm \
      /var/lib/vault-agent /var/run/vault-agent

COPY --from=vault-bin /bin/vault /usr/local/bin/vault

COPY --from=python-build /build/wheels /tmp/wheels
COPY agentswarm/requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-index --find-links=/tmp/wheels -r /tmp/requirements.txt \
    && rm -rf /tmp/wheels /tmp/requirements.txt

COPY --chown=root:root scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY --chown=root:root scripts/wait-for-secrets.sh   /usr/local/bin/wait-for-secrets.sh
COPY --chown=root:root vault-agent/agent.hcl         /etc/vault-agent/agent.hcl
COPY --chown=root:root vault-agent/supervisord.conf  /etc/agentswarm/supervisord.conf
COPY --chown=root:root templates/                    /etc/vault-agent/templates/
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/wait-for-secrets.sh

COPY --chown=agentswarm:agentswarm agentswarm/ /opt/agentswarm/

USER agentswarm
WORKDIR /opt/agentswarm

EXPOSE 8080

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    VAULT_AGENT_CONFIG=/etc/vault-agent/agent.hcl \
    AGENTSWARM_ENV_FILE=/etc/agentswarm/secrets/runtime.env

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/healthz || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["python", "-m", "agentswarm"]
