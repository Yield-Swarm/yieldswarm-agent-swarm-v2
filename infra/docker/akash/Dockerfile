FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl jq tini \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app

RUN chmod 0755 /app/infra/docker/akash/entrypoint.sh

ENTRYPOINT ["/usr/bin/tini", "--", "/app/infra/docker/akash/entrypoint.sh"]
CMD ["python", "agents/akash-optimizer.py"]
