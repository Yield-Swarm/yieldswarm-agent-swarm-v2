# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Stage 1: fetch a pinned, checksum-verified Vault CLI binary.
# ---------------------------------------------------------------------------
FROM debian:12-slim AS vault-cli

ARG VAULT_VERSION=1.18.1
ARG TARGETARCH=amd64

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates unzip gnupg; \
    rm -rf /var/lib/apt/lists/*; \
    cd /tmp; \
    base="https://releases.hashicorp.com/vault/${VAULT_VERSION}"; \
    curl -fsSL -o vault.zip          "${base}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip"; \
    curl -fsSL -o vault_SHA256SUMS   "${base}/vault_${VAULT_VERSION}_SHA256SUMS"; \
    grep " vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip\$" vault_SHA256SUMS | sha256sum -c -; \
    unzip vault.zip; \
    install -m 0755 vault /usr/local/bin/vault; \
    /usr/local/bin/vault version

# ---------------------------------------------------------------------------
# Stage 2: application runtime.
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

# jq is required by entrypoint.sh; tini gives us correct PID 1 signal handling.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends jq tini ca-certificates; \
    rm -rf /var/lib/apt/lists/*

COPY --from=vault-cli /usr/local/bin/vault /usr/local/bin/vault

# Create an unprivileged user to run the application.
RUN useradd --system --create-home --uid 10001 --shell /usr/sbin/nologin yieldswarm

WORKDIR /app

# Install Python dependencies first for better layer caching. The file is
# optional — the build still succeeds if it is absent.
COPY requirements.txt* /app/
RUN if [ -f /app/requirements.txt ]; then \
        pip install --no-cache-dir -r /app/requirements.txt; \
    fi

# Application source.
COPY agents/ /app/agents/

# Runtime secret-injection entrypoint.
COPY deploy/akash/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh

USER 10001

# Conservative defaults — override per deployment via the Akash SDL.
ENV VAULT_KV_MOUNT=secret \
    VAULT_APP_PATH=yieldswarm/app \
    VAULT_RPC_PATH=yieldswarm/rpc \
    VAULT_APPROLE_PATH=approle \
    VAULT_REVOKE_TOKEN_AFTER_LOAD=true \
    PYTHONUNBUFFERED=1

# tini -> entrypoint (fetch + inject secrets) -> application command.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["python", "/app/agents/akash-optimizer.py"]
