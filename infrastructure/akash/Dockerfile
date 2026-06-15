# =============================================================================
# YieldSwarm OpenClaw container for Akash deployments.
#
# Multi-stage:
#   1. builder: pulls a known-good `vault` binary + verifies checksum.
#   2. runtime: distroless-ish slim Python base with the entrypoint and the
#      app source. NO secrets are baked in. Everything sensitive is fetched
#      from Vault by /usr/local/bin/entrypoint.sh at container start.
# =============================================================================

ARG PYTHON_VERSION=3.12
ARG VAULT_VERSION=1.17.2

# ----- Stage 1: vault binary -------------------------------------------------
FROM debian:bookworm-slim AS vault-fetcher
ARG VAULT_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates unzip gnupg \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp
RUN curl -fsSL -o vault.zip \
      "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" \
 && curl -fsSL -o vault.sha256 \
      "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS" \
 && grep "vault_${VAULT_VERSION}_linux_amd64.zip" vault.sha256 \
      | sha256sum -c - \
 && unzip vault.zip \
 && chmod +x vault

# ----- Stage 2: runtime ------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl jq tini dumb-init \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --system --gid 10001 yieldswarm \
 && useradd  --system --uid 10001 --gid yieldswarm --home /home/yieldswarm \
             --create-home --shell /usr/sbin/nologin yieldswarm

COPY --from=vault-fetcher /tmp/vault /usr/local/bin/vault

WORKDIR /app
COPY infrastructure/akash/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY infrastructure/akash/healthcheck.sh /usr/local/bin/healthcheck.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Application source - mounted in via CI; placeholder if built standalone.
COPY agents/ /app/agents/
COPY crons/  /app/crons/
COPY council/ /app/council/

# Drop privileges; entrypoint will only need to write to /tmp.
USER yieldswarm

# Defaults overridable via SDL env block.
ENV VAULT_ADDR="" \
    VAULT_ROLE="yieldswarm-akash" \
    VAULT_KV_MOUNT="kv" \
    VAULT_SECRET_ROOT="yieldswarm" \
    VAULT_RUNTIME_PATH="runtime/openclaw" \
    VAULT_RPC_PATH="rpc" \
    APP_CMD="python -u /app/agents/openclaw-scaler.py"

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD ["/usr/local/bin/healthcheck.sh"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD []
