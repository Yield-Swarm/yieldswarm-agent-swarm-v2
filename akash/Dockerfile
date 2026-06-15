# syntax=docker/dockerfile:1.7
# =========================================================================
# YieldSwarm Akash worker image.
#
# Design:
#   - The container ships a Vault Agent binary that runs as PID 1's sidecar.
#   - At boot, entrypoint.sh consumes the wrapped SecretID injected by the
#     Akash deployment (env: VAULT_WRAPPED_SECRET_ID), unwraps it, and
#     authenticates the AppRole.
#   - Vault Agent renders /run/secrets/agent.env from a Consul-Template
#     against KVv2, then keeps the token + secrets fresh.
#   - The actual YieldSwarm python process is started by the entrypoint
#     once the env file exists, with env-vars sourced from /run/secrets.
#   - Nothing sensitive is ever baked into the image or written to disk
#     outside of an in-memory tmpfs.
# =========================================================================

ARG VAULT_VERSION=1.18.2
ARG PYTHON_VERSION=3.12-slim-bookworm

FROM hashicorp/vault:${VAULT_VERSION} AS vault-bin

FROM python:${PYTHON_VERSION} AS base
ARG TARGETARCH

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VAULT_AGENT_CONFIG=/etc/vault-agent/vault-agent.hcl \
    AGENT_ENV_FILE=/run/secrets/agent.env

# ---- OS deps ------------------------------------------------------------
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates curl jq tini gettext-base dumb-init \
 && rm -rf /var/lib/apt/lists/*

# ---- Bring in Vault binary from official image (pinned) ----------------
COPY --from=vault-bin /bin/vault /usr/local/bin/vault
RUN chmod 0755 /usr/local/bin/vault && /usr/local/bin/vault version

# ---- Non-root user ------------------------------------------------------
RUN groupadd --system --gid 1500 yieldswarm \
 && useradd  --system --uid 1500 --gid yieldswarm \
        --home-dir /home/yieldswarm --create-home --shell /bin/bash \
        yieldswarm

# ---- App layer ----------------------------------------------------------
WORKDIR /app
COPY --chown=yieldswarm:yieldswarm requirements.txt /app/requirements.txt
RUN pip install --require-hashes --no-deps -r /app/requirements.txt \
    || pip install -r /app/requirements.txt

COPY --chown=yieldswarm:yieldswarm . /app

# ---- Vault Agent config -------------------------------------------------
RUN mkdir -p /etc/vault-agent/templates /run/secrets \
 && chown -R yieldswarm:yieldswarm /etc/vault-agent /run/secrets \
 && chmod 0750 /etc/vault-agent /run/secrets

COPY akash/vault-agent.hcl           /etc/vault-agent/vault-agent.hcl
COPY akash/templates/agent.env.ctmpl /etc/vault-agent/templates/agent.env.ctmpl
COPY akash/entrypoint.sh             /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh \
 && chmod 0640 /etc/vault-agent/vault-agent.hcl \
                /etc/vault-agent/templates/agent.env.ctmpl

# /run/secrets is a tmpfs mount in the Akash SDL so it never touches disk.
VOLUME ["/run/secrets"]

USER yieldswarm:yieldswarm

# tini handles signals and reaps the Vault Agent + workload sub-processes.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["python", "-m", "yieldswarm.agent"]
