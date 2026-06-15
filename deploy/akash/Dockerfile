FROM python:3.12-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    jq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY agents ./agents
COPY mining ./mining
COPY deploy/akash/entrypoint.sh /usr/local/bin/yieldswarm-vault-entrypoint

RUN chmod 0755 /usr/local/bin/yieldswarm-vault-entrypoint

ENTRYPOINT ["yieldswarm-vault-entrypoint"]
CMD ["python", "agents/akash-optimizer.py"]
