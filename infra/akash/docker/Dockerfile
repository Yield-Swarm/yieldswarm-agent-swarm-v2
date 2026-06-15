# syntax=docker/dockerfile:1.7
#
# YieldSwarm AgentSwarm OS - Akash deployment image.
#
# Hard rule: NO secret value is ever baked into a layer.  The only Vault-related
# material present at build time is the public CA bundle and the AppRole
# role_id (which is half of the credential and useless alone).  The matching
# secret_id is delivered at deploy time as a response-wrapped token via the
# AKASH_VAULT_SECRET_ID_WRAPPED env var (single-use, short TTL).

##############################################################################
# Stage 1 - build / vendor app deps
##############################################################################
FROM python:3.12-slim AS app-build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# Lock files would normally be copied here; this repo currently has placeholder
# agents only, so we install the minimal runtime.
RUN pip install --prefix=/install \
        "requests==2.32.3" \
        "tenacity==9.0.0" \
        "hvac==2.3.0"

##############################################################################
# Stage 2 - fetch Vault binary (pinned + sha256-verified)
##############################################################################
FROM debian:bookworm-slim AS vault-fetch

ARG VAULT_VERSION=1.17.6
ARG TARGETARCH=amd64
ARG VAULT_SHA256=2c4a9d5c2f3a1d8d4eebb1c6e3f7c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1c1
# The checksum above is intentionally a placeholder; CI must override with the
# real value from https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/vault
RUN curl -fsSLo vault.zip \
      "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip" \
 && curl -fsSLo vault.SHA256SUMS \
      "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS" \
 && grep "linux_${TARGETARCH}.zip" vault.SHA256SUMS | sha256sum -c - \
 && unzip vault.zip -d /usr/local/bin \
 && chmod 0755 /usr/local/bin/vault \
 && /usr/local/bin/vault --version

##############################################################################
# Stage 3 - runtime
##############################################################################
FROM python:3.12-slim AS runtime

ARG APP_UID=10001
ARG APP_GID=10001

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        ca-certificates \
        tini \
        jq \
        curl \
        gosu \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd -g ${APP_GID} app \
 && useradd  -u ${APP_UID} -g app -m -s /usr/sbin/nologin app \
 && install -d -o app -g app -m 0750 /app /etc/vault-agent /etc/vault-agent/templates \
 && install -d -m 0700 /run/vault-agent

COPY --from=vault-fetch /usr/local/bin/vault /usr/local/bin/vault
COPY --from=app-build   /install              /usr/local

COPY infra/vault/agent/vault-agent.hcl              /etc/vault-agent/agent.hcl
COPY infra/vault/agent/templates/app.env.ctmpl      /etc/vault-agent/templates/app.env.ctmpl
COPY infra/akash/docker/entrypoint.sh               /usr/local/bin/entrypoint.sh
COPY infra/akash/docker/healthcheck.sh              /usr/local/bin/healthcheck.sh
COPY agents/                                        /app/agents/

# role_id is the non-secret half of the AppRole credential.  It is supplied
# at *build* time so that a compromised registry pull still cannot impersonate
# the workload without also possessing the secret_id (delivered at deploy
# time, wrapped, single-use).
ARG VAULT_APPROLE_ROLE_ID
RUN test -n "${VAULT_APPROLE_ROLE_ID}" || (echo "VAULT_APPROLE_ROLE_ID build-arg required" && exit 1) \
 && printf '%s' "${VAULT_APPROLE_ROLE_ID}" > /etc/vault-agent/role_id \
 && chown root:app /etc/vault-agent/role_id \
 && chmod 0440     /etc/vault-agent/role_id

RUN chmod 0755 /usr/local/bin/entrypoint.sh /usr/local/bin/healthcheck.sh

ENV VAULT_ADDR="" \
    YS_ENV="prod" \
    APP_ENV_FILE="/run/vault-agent/app.env" \
    PATH="/usr/local/bin:${PATH}"

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh

# Run as root just long enough to set up tmpfs + drop privileges; the
# entrypoint immediately `exec`s into `gosu app`.
USER root
WORKDIR /app
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
CMD ["python", "-u", "/app/agents/akash-optimizer.py"]
