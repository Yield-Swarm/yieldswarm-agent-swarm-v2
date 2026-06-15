FROM python:3.12-slim-bookworm AS base

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY agents/ ./agents/
COPY lib/ ./lib/
COPY deploy/akash/entrypoint.sh /entrypoint.sh

RUN chmod 755 /entrypoint.sh \
    && useradd --create-home --shell /usr/sbin/nologin agentswarm \
    && mkdir -p /run/secrets /vault/config /vault/templates \
    && chown -R agentswarm:agentswarm /app /run/secrets /vault

USER agentswarm

# Runtime-only — supplied by Akash SDL at deploy time, never baked into the image.
ENV VAULT_KV_MOUNT=yieldswarm \
    VAULT_SECRET_PATHS=akash,rpc,runpod \
    SECRETS_FILE=/run/secrets/app.env \
    HEALTH_PORT=8080 \
    PYTHONUNBUFFERED=1

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -sf "http://127.0.0.1:${HEALTH_PORT}/health" || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["python", "agents/akash-optimizer.py"]
