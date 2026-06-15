# =============================================================================
# YieldSwarm agent image — Vault-aware, zero baked-in secrets.
# The entrypoint fetches all secrets from Vault at runtime and exports them
# before exec'ing the workload. Build context is the repository root:
#   docker build -f infra/akash/Dockerfile -t <registry>/yieldswarm-agents:<tag> .
# =============================================================================
FROM python:3.12-slim AS base

# Runtime deps for the entrypoint (curl + jq) and TLS roots.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl jq ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Non-root runtime user — never run the swarm as root.
RUN groupadd --system --gid 10001 swarm \
    && useradd  --system --uid 10001 --gid swarm --create-home --home-dir /app swarm

WORKDIR /app

# Install Python deps first for better layer caching. requirements.txt is
# optional; the build succeeds even if it is absent.
COPY requirements.txt* ./
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi

# Application source.
COPY agents/ ./agents/

# Vault-aware entrypoint.
COPY infra/akash/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0555 /usr/local/bin/entrypoint.sh

USER swarm:swarm

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    VAULT_KV_MOUNT=kv

# Liveness: confirm the entrypoint reached the workload (PID 1 running python).
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD pgrep -f "python" >/dev/null || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
# Default workload — override per Akash service as needed.
CMD ["python", "-u", "agents/akash-optimizer.py"]
