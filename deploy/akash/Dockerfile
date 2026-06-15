FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl jq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN groupadd --gid 10001 app \
  && useradd --uid 10001 --gid 10001 --create-home --shell /usr/sbin/nologin app

COPY agents/ /app/agents/
COPY deploy/akash/entrypoint.sh /usr/local/bin/akash-entrypoint.sh
RUN chmod 0750 /usr/local/bin/akash-entrypoint.sh \
  && chown -R app:app /app

USER app

ENTRYPOINT ["/usr/local/bin/akash-entrypoint.sh"]
CMD ["python", "/app/agents/akash-optimizer.py"]
