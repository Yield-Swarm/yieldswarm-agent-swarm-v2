FROM python:3.12-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl jq ca-certificates \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd --system appgroup && useradd --system --gid appgroup --create-home appuser

WORKDIR /app

COPY agents/ /app/agents/
COPY deploy/akash/entrypoint.sh /opt/yieldswarm/entrypoint.sh

RUN chmod 0550 /opt/yieldswarm/entrypoint.sh \
  && chown -R appuser:appgroup /app /opt/yieldswarm

USER appuser

ENTRYPOINT ["/opt/yieldswarm/entrypoint.sh"]
CMD ["python", "/app/agents/akash-optimizer.py"]
