version: "2.0"

services:
  akash-optimizer:
    image: ${AKASH_IMAGE}
    env:
      - VAULT_ADDR=${VAULT_ADDR}
      - VAULT_ROLE_ID=${VAULT_ROLE_ID}
      - VAULT_SECRET_ID=${VAULT_SECRET_ID}
      - VAULT_KV_MOUNT=${VAULT_KV_MOUNT}
      - VAULT_SECRET_PATH=${VAULT_SECRET_PATH}
      - REQUIRED_SECRET_KEYS=${REQUIRED_SECRET_KEYS}

profiles:
  compute:
    akash-optimizer:
      resources:
        cpu:
          units: 1
        memory:
          size: 1Gi
        storage:
          size: 2Gi
  placement:
    dcloud:
      pricing:
        akash-optimizer:
          denom: uakt
          amount: 1000
  deployment:
    akash-optimizer:
      dcloud:
        profile: akash-optimizer
        count: 1
