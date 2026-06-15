FROM python:3.12-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl tini \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY agents ./agents
COPY docker/akash/entrypoint.sh /usr/local/bin/akash-vault-entrypoint

RUN chmod 0555 /usr/local/bin/akash-vault-entrypoint

USER 65532:65532

ENTRYPOINT ["tini", "--", "/usr/local/bin/akash-vault-entrypoint"]
CMD ["python", "/app/agents/akash-optimizer.py"]
