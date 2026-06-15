FROM python:3.12-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      gpg \
      jq \
      lsb-release \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg \
    && chmod 0644 /etc/apt/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends vault \
    && apt-get purge -y --auto-remove curl gpg lsb-release \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /usr/sbin/nologin --uid 10001 yieldswarm

WORKDIR /app

COPY agents/ /app/agents/
COPY akash/bin/entrypoint.sh /usr/local/bin/akash-entrypoint.sh

RUN chmod 0755 /usr/local/bin/akash-entrypoint.sh \
    && chown -R yieldswarm:yieldswarm /app

USER yieldswarm

ENTRYPOINT ["/usr/local/bin/akash-entrypoint.sh"]
CMD ["python", "/app/agents/akash-optimizer.py"]
