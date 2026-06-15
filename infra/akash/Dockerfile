# syntax=docker/dockerfile:1.7
# ---------------------------------------------------------------------------
# APN AgentSwarm runtime image for Akash deployments.
#
# Design:
#   - Multi-stage build. Stage 1 pulls the Vault Agent binary from the
#     official HashiCorp image so we never compile or download it at
#     runtime.
#   - Stage 2 is a slim Python base for the agent runtime. The entrypoint
#     starts Vault Agent first, blocks until secrets render, then execs
#     the swarm process. Nothing in the image embeds API keys.
# ---------------------------------------------------------------------------

ARG VAULT_VERSION=1.17.6
ARG PYTHON_VERSION=3.12.5

FROM hashicorp/vault:${VAULT_VERSION} AS vault

FROM python:${PYTHON_VERSION}-slim-bookworm

ARG APN_UID=10001
ARG APN_GID=10001

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    APN_HOME=/opt/apn \
    VAULT_SECRETS_DIR=/run/apn/secrets \
    VAULT_RUN_DIR=/run/apn/vault

RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
        ca-certificates curl jq tini gosu; \
    rm -rf /var/lib/apt/lists/*; \
    groupadd --system --gid "${APN_GID}" apn; \
    useradd  --system --uid "${APN_UID}" --gid apn \
             --home "${APN_HOME}" --shell /usr/sbin/nologin apn; \
    install -d -m 0750 -o apn -g apn "${APN_HOME}" "${VAULT_SECRETS_DIR}" "${VAULT_RUN_DIR}"

COPY --from=vault /bin/vault /usr/local/bin/vault

WORKDIR ${APN_HOME}

COPY --chown=apn:apn agents/ ./agents/
COPY --chown=root:root infra/akash/entrypoint.sh        /usr/local/bin/apn-entrypoint
COPY --chown=root:root infra/akash/vault-agent.hcl      /etc/vault-agent/vault-agent.hcl
COPY --chown=root:root infra/akash/templates/           /etc/vault-agent/templates/

RUN chmod 0755 /usr/local/bin/apn-entrypoint; \
    chmod -R 0644 /etc/vault-agent/templates/*; \
    chmod 0644 /etc/vault-agent/vault-agent.hcl

# tini reaps Vault Agent / agent children cleanly on SIGTERM.
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/apn-entrypoint"]

CMD ["python", "-m", "agents.akash_optimizer"]
