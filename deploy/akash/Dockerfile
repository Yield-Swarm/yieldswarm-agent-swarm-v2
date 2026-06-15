FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl jq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY agents/ /app/agents/
COPY deploy/akash/entrypoint.sh /usr/local/bin/akash-entrypoint

RUN chmod 0555 /usr/local/bin/akash-entrypoint

USER 65532:65532

ENTRYPOINT ["/usr/local/bin/akash-entrypoint"]
CMD ["python", "/app/agents/akash-optimizer.py"]
