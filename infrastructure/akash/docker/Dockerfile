# syntax=docker/dockerfile:1.7

############################################################
# 1. Builder stage - pulls a pinned Vault CLI binary.
############################################################
ARG VAULT_VERSION=1.18.2
ARG PYTHON_VERSION=3.12

FROM hashicorp/vault:${VAULT_VERSION} AS vault-bin
# We only need the binary; the upstream image already places it at
# /bin/vault. Copy it out in the next stage.

############################################################
# 2. Runtime stage - minimal, non-root, no shell secrets.
############################################################
FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    # Vault entrypoint defaults - can be overridden at deploy time.
    VAULT_ADDR="" \
    VAULT_NAMESPACE="" \
    VAULT_APPROLE_MOUNT="approle" \
    VAULT_KV_MOUNT="secret" \
    VAULT_SECRET_BASE="yieldswarm" \
    VAULT_ROLE_ID="" \
    VAULT_SECRET_ID="" \
    VAULT_WRAPPED_SECRET_ID="" \
    VAULT_TOKEN_RENEW_INTERVAL=600 \
    VAULT_BOOTSTRAP_TIMEOUT=30 \
    YIELDSWARM_RUN_AS=app

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        tini \
        gosu; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd --system --gid 10001 app; \
    useradd  --system --uid 10001 --gid app --home-dir /app --shell /usr/sbin/nologin app; \
    install -d -m 0750 -o app -g app /app /app/data; \
    # Vault writes secrets to a tmpfs path mounted at runtime.
    install -d -m 0700 -o app -g app /run/yieldswarm

COPY --from=vault-bin /bin/vault /usr/local/bin/vault
RUN chmod 0755 /usr/local/bin/vault && /usr/local/bin/vault -version

WORKDIR /app

# Application payload. Replace this COPY with whatever ships your wheels
# / static assets; the entrypoint contract (env-fed secrets) is stable.
COPY --chown=app:app app/ /app/

COPY --chown=root:root entrypoint.sh   /usr/local/bin/entrypoint.sh
COPY --chown=root:root healthcheck.sh  /usr/local/bin/healthcheck.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

# Drop capabilities at runtime. Akash containers run as root by default;
# the entrypoint will `gosu app` once secrets are resolved.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# tini = PID 1, reaps zombies, forwards SIGTERM cleanly to entrypoint.sh,
# entrypoint.sh forwards to the child workload.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["python", "-m", "yieldswarm.agentswarm"]
