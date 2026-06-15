---
version: "2.0"

services:
  yieldswarm-akash:
    image: ${AKASH_IMAGE}
    env:
      - VAULT_ADDR=${VAULT_ADDR}
      - VAULT_NAMESPACE=${VAULT_NAMESPACE}
      - VAULT_KV_MOUNT=${VAULT_KV_MOUNT}
      - VAULT_AKASH_SECRET_PATH=${VAULT_AKASH_SECRET_PATH}
      - VAULT_RPC_SECRET_PATH=${VAULT_RPC_SECRET_PATH}
      - VAULT_ROLE_ID=${VAULT_ROLE_ID}
      - VAULT_WRAPPED_SECRET_ID=${VAULT_WRAPPED_SECRET_ID}
      - REQUIRED_RUNTIME_ENV=${REQUIRED_RUNTIME_ENV}
    expose:
      - port: 8080
        as: 8080
        to:
          - global: false

profiles:
  compute:
    yieldswarm-akash:
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
        yieldswarm-akash:
          denom: uakt
          amount: ${AKASH_PRICE_UAKT}

deployment:
  yieldswarm-akash:
    dcloud:
      profile: yieldswarm-akash
      count: ${AKASH_COUNT}
