FROM python:3.12-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl jq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . /app
COPY infra/akash/entrypoint.sh /usr/local/bin/akash-entrypoint
RUN chmod 0755 /usr/local/bin/akash-entrypoint

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/usr/local/bin/akash-entrypoint"]
CMD ["python3", "agents/chainlink-vault-manager.py"]
