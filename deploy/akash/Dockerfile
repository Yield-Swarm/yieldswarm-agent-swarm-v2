FROM hashicorp/vault:1.18.4 AS vault

FROM python:3.12-slim

RUN apt-get update \
  && apt-get install --yes --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 appuser

COPY --from=vault /bin/vault /usr/local/bin/vault

WORKDIR /app

COPY agents/akash-optimizer.py /app/agents/akash-optimizer.py
COPY deploy/akash/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0500 /usr/local/bin/entrypoint.sh \
  && chown -R appuser:appuser /app

USER appuser

ENV PYTHONUNBUFFERED=1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["python", "/app/agents/akash-optimizer.py"]
