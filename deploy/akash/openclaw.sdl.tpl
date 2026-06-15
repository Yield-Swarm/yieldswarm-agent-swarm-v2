version: "2.0"

services:
  openclaw:
    image: ${OPENCLAW_IMAGE}
    env:
      - PYTHONUNBUFFERED=1
      - OPENCLAW_ENVIRONMENT=${OPENCLAW_ENVIRONMENT}
      - VAULT_ADDR=${VAULT_ADDR}
      - VAULT_NAMESPACE=${VAULT_NAMESPACE}
      - VAULT_AUTH_PATH=${VAULT_AUTH_PATH}
      - VAULT_KV_MOUNT=${VAULT_KV_MOUNT}
      - VAULT_SECRET_PATH=${VAULT_SECRET_PATH}
      - VAULT_ROLE_ID=${VAULT_ROLE_ID}
      - VAULT_WRAPPED_SECRET_ID=${VAULT_WRAPPED_SECRET_ID}
      - VAULT_CACERT_B64=${VAULT_CACERT_B64}
      - VAULT_SECRET_JSON_FILE=/run/secrets/openclaw-runtime.json

profiles:
  compute:
    openclaw:
      resources:
        cpu:
          units: 1
        memory:
          size: 2Gi
        storage:
          - size: 5Gi
  placement:
    akash:
      pricing:
        openclaw:
          denom: uakt
          amount: 10000

deployment:
  openclaw:
    akash:
      profile: openclaw
      count: 1
