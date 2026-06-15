version: "2.0"

services:
  agentswarm:
    image: ${IMAGE}
    env:
      - VAULT_ADDR=${VAULT_ADDR}
      - VAULT_NAMESPACE=${VAULT_NAMESPACE}
      - VAULT_AUTH_PATH=${VAULT_AUTH_PATH}
      - VAULT_ROLE_ID=${VAULT_ROLE_ID}
      - VAULT_WRAPPED_SECRET_ID_TOKEN=${VAULT_WRAPPED_SECRET_ID_TOKEN}
      - VAULT_KV_MOUNT=${VAULT_KV_MOUNT}
      - VAULT_SECRET_PATH=${VAULT_SECRET_PATH}
      - VAULT_CACERT_PATH=${VAULT_CACERT_PATH}
      - VAULT_SKIP_VERIFY=${VAULT_SKIP_VERIFY}
      - VAULT_MAX_ATTEMPTS=${VAULT_MAX_ATTEMPTS}
      - VAULT_RETRY_BACKOFF_SECONDS=${VAULT_RETRY_BACKOFF_SECONDS}

profiles:
  compute:
    agentswarm:
      resources:
        cpu:
          units: ${AKASH_CPU_UNITS}
        memory:
          size: ${AKASH_MEMORY_SIZE}
        storage:
          - size: ${AKASH_STORAGE_SIZE}
  placement:
    dcloud:
      pricing:
        agentswarm:
          denom: uakt
          amount: ${AKASH_PRICE_AMOUNT}

deployment:
  agentswarm:
    dcloud:
      profile: agentswarm
      count: ${AKASH_REPLICAS}
