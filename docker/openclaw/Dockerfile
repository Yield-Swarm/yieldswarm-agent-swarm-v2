FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY agents /app/agents
COPY docker/openclaw/entrypoint.sh /usr/local/bin/openclaw-entrypoint

RUN chmod 0500 /usr/local/bin/openclaw-entrypoint

USER 65532:65532

ENTRYPOINT ["/usr/local/bin/openclaw-entrypoint"]
CMD ["python3", "-u", "/app/agents/openclaw-scaler.py"]
