# akash/Dockerfile
#
# Production image for the YieldSwarm agent workload deployed on Akash.
# Secrets are NEVER baked into the image. The container starts vault-agent
# in auto-auth mode (AppRole), which:
#   1. Unwraps the one-shot secret_id wrap token delivered via env at deploy time.
#   2. Logs into Vault and obtains a short-lived token.
#   3. Renews the token in the background.
#   4. Renders /run/secrets/env from a template, then the entrypoint exports it
#      into the app's environment and execs the app.
#
# Multi-stage so the final image has no build toolchain.

# ---------- builder ----------
FROM python:3.12-slim-bookworm AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build
COPY app/requirements.txt ./
RUN pip install --prefix=/install -r requirements.txt

# ---------- runtime ----------
FROM python:3.12-slim-bookworm AS runtime

ARG VAULT_VERSION=1.17.6
ARG TARGETARCH=amd64

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/usr/local/bin:${PATH}"

# - ca-certificates: TLS to Vault and to provider APIs
# - curl, unzip: install vault binary
# - tini: PID 1 that reaps zombies + forwards signals (clean shutdown of vault-agent)
# - gosu: drop privileges after entrypoint setup
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates curl unzip tini gosu; \
    rm -rf /var/lib/apt/lists/*; \
    curl -fsSL -o /tmp/vault.zip \
        "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip"; \
    unzip /tmp/vault.zip -d /usr/local/bin; \
    chmod +x /usr/local/bin/vault; \
    rm /tmp/vault.zip; \
    vault --version

# Non-root runtime user.
RUN groupadd --system --gid 1000 yieldswarm && \
    useradd  --system --uid 1000 --gid 1000 --home /app --shell /sbin/nologin yieldswarm

# tmpfs-friendly secret render dir; mode 0750 so only the app user + group can read.
RUN install -d -o yieldswarm -g yieldswarm -m 0750 /run/secrets && \
    install -d -o yieldswarm -g yieldswarm -m 0750 /var/run/vault

COPY --from=builder /install /usr/local
COPY app/                  /app/
COPY vault-agent/          /etc/vault-agent/
COPY entrypoint.sh         /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/entrypoint.sh && \
    chown -R yieldswarm:yieldswarm /app /etc/vault-agent

WORKDIR /app

# Lightweight readiness probe: vault-agent writes /run/secrets/env once the
# template has rendered successfully. We treat its presence as "ready".
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD test -s /run/secrets/env || exit 1

EXPOSE 8080

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["python", "-u", "/app/server.py"]
