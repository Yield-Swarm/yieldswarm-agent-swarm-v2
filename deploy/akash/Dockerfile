FROM hashicorp/vault:1.18 AS vault-bin

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd --system app && useradd --system --gid app --create-home app

COPY --from=vault-bin /bin/vault /usr/local/bin/vault
COPY agents /app/agents
COPY deploy/akash/entrypoint.sh /app/entrypoint.sh

RUN chmod 0755 /app/entrypoint.sh \
  && chown -R app:app /app

USER app
WORKDIR /app

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["python", "/app/agents/akash-optimizer.py"]
