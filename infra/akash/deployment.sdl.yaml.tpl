---
version: "2.0"

services:
  agentswarm:
    image: ${AKASH_IMAGE}
    env:
      - "APP_ENV=${APP_ENV}"
      - "APP_START_COMMAND=${APP_START_COMMAND}"
      - "VAULT_ADDR=${VAULT_ADDR}"
      - "VAULT_NAMESPACE=${VAULT_NAMESPACE}"
      - "VAULT_KV_MOUNT=${VAULT_KV_MOUNT}"
      - "VAULT_SECRET_PATH=${VAULT_SECRET_PATH}"
      - "VAULT_APPROLE_ROLE_ID=${VAULT_APPROLE_ROLE_ID}"
      - "VAULT_WRAPPED_SECRET_ID=${VAULT_WRAPPED_SECRET_ID}"
      - "VAULT_REQUIRED_SECRET_KEYS=${VAULT_REQUIRED_SECRET_KEYS}"
      - "VAULT_REVOKE_TOKEN_AFTER_RENDER=true"

profiles:
  compute:
    agentswarm:
      resources:
        cpu:
          units: ${AKASH_CPU}
        memory:
          size: ${AKASH_MEMORY}
        storage:
          - size: ${AKASH_EPHEMERAL_SIZE}
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
      count: ${AKASH_REPLICA_COUNT}
