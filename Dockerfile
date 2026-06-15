FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    HOST=0.0.0.0 \
    ODYSSEUS_SERVICE_NAME=odysseus \
    ODYSSEUS_AGENT_COUNT=84 \
    ODYSSEUS_GPU_COUNT=1 \
    ODYSSEUS_RUNTIME_VAULT_PATH=kv/data/yieldswarm/odysseus/runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY services/ /app/services/
COPY scripts/lib/vault-env.sh /usr/local/lib/yieldswarm/vault-env.sh
COPY docker/entrypoint-odysseus.sh /usr/local/bin/entrypoint-odysseus.sh

RUN chmod 0755 /usr/local/bin/entrypoint-odysseus.sh /usr/local/lib/yieldswarm/vault-env.sh

EXPOSE 8080

ENTRYPOINT ["entrypoint-odysseus.sh"]
CMD ["python", "-m", "services.odysseus.main"]
