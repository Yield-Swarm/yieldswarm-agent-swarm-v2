---
version: "2.0"

services:
  yieldswarm:
    image: ${AKASH_IMAGE}
    command:
      - python
      - agents/akash-optimizer.py
    env:
      - VAULT_ADDR=${VAULT_ADDR}
      - VAULT_NAMESPACE=${VAULT_NAMESPACE}
      - VAULT_AUTH_PATH=${VAULT_AUTH_PATH}
      - VAULT_KV_MOUNT=${VAULT_KV_MOUNT}
      - VAULT_ROLE_ID=${VAULT_ROLE_ID}
      - VAULT_WRAPPED_SECRET_ID=${VAULT_WRAPPED_SECRET_ID}
      - VAULT_SECRET_PATHS=cloud/azure,cloud/runpod,cloud/vultr,cloud/digitalocean,rpc
    expose:
      - port: 8080
        as: 80
        to:
          - global: true

profiles:
  compute:
    yieldswarm:
      resources:
        cpu:
          units: 1
        memory:
          size: 1Gi
        storage:
          size: 2Gi
  placement:
    akash:
      pricing:
        yieldswarm:
          denom: uakt
          amount: 1000

deployment:
  yieldswarm:
    akash:
      profile: yieldswarm
      count: 1
