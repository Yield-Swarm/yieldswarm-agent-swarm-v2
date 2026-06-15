version: "2.0"

services:
  yieldswarm-agent:
    image: ${AKASH_IMAGE}
    command:
      - /usr/local/bin/akash-entrypoint.sh
    args:
      - python
      - /app/agents/akash-optimizer.py
    env:
      - VAULT_ADDR=${VAULT_ADDR}
      - VAULT_NAMESPACE=${VAULT_NAMESPACE}
      - VAULT_KV_MOUNT=${VAULT_KV_MOUNT}
      - VAULT_APPROLE_MOUNT=${VAULT_APPROLE_MOUNT}
      - VAULT_SECRET_PATHS=${VAULT_SECRET_PATHS}
      - VAULT_ROLE_ID=${VAULT_ROLE_ID}
      - VAULT_WRAP_TOKEN=${VAULT_WRAP_TOKEN}
      - VAULT_REVOKE_TOKEN_AFTER_LOAD=${VAULT_REVOKE_TOKEN_AFTER_LOAD}
      - VAULT_EXPORT_TOKEN_TO_CHILD=${VAULT_EXPORT_TOKEN_TO_CHILD}
      - LOG_LEVEL=${LOG_LEVEL}
    expose:
      - port: 8080
        as: 80
        to:
          - global: true

profiles:
  compute:
    yieldswarm-agent:
      resources:
        cpu:
          units: ${AKASH_CPU_UNITS}
        memory:
          size: ${AKASH_MEMORY_SIZE}
        storage:
          size: ${AKASH_STORAGE_SIZE}
  placement:
    akash:
      pricing:
        yieldswarm-agent:
          denom: ${AKASH_DENOM}
          amount: ${AKASH_BID_AMOUNT}

deployment:
  yieldswarm-agent:
    akash:
      profile: yieldswarm-agent
      count: ${AKASH_REPLICA_COUNT}
