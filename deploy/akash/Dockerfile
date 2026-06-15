FROM hashicorp/vault:1.21.7 AS vault

FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates jq \
    && rm -rf /var/lib/apt/lists/*

COPY --from=vault /bin/vault /usr/local/bin/vault

RUN useradd --create-home --shell /usr/sbin/nologin appuser \
    && mkdir -p /app /run/secrets \
    && chown -R appuser:appuser /app /run/secrets

WORKDIR /app
COPY . /app

RUN chmod 0755 /app/deploy/akash/entrypoint.sh /app/deploy/akash/render_vault_env.py \
    && chown -R appuser:appuser /app /run/secrets

USER appuser

ENTRYPOINT ["/app/deploy/akash/entrypoint.sh"]
CMD ["python", "agents/akash-optimizer.py"]
