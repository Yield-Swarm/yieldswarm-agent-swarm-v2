FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/*

COPY . /app
COPY deploy/akash/entrypoint.sh /opt/akash/entrypoint.sh

RUN chmod 0750 /opt/akash/entrypoint.sh

ENTRYPOINT ["/opt/akash/entrypoint.sh"]
CMD ["python", "/app/agents/akash-optimizer.py"]
