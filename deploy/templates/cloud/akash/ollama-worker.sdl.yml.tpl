# Akash GPU worker — env-driven SDL template
# Render: envsubst < deploy/templates/cloud/akash/ollama-worker.sdl.yml.tpl > /tmp/ollama.sdl.yml
version: "2.0"

services:
  ollama:
    image: ${OLLAMA_IMAGE}
    expose:
      - port: 11434
        as: 11434
        to:
          - global: true
    env:
      - OLLAMA_HOST=0.0.0.0:11434
      - OLLAMA_PULL_MODELS=${OLLAMA_PULL_MODELS}
      - OLLAMA_PULL_TIMEOUT=${OLLAMA_PULL_TIMEOUT}
    command:
      - /bin/sh
      - -c
      - >
        ollama serve & srv=$$!;
        for i in $$(seq 1 $${OLLAMA_PULL_TIMEOUT}); do
        curl -fsS http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break;
        kill -0 "$$srv" 2>/dev/null || { wait "$$srv"; exit 1; };
        sleep 1; done;
        for m in $$(echo "$${OLLAMA_PULL_MODELS}" | tr ',' ' '); do
        [ -n "$$m" ] && ollama pull "$$m" || true; done;
        wait "$$srv"

profiles:
  compute:
    ollama:
      resources:
        cpu:
          units: "${AKASH_CPU_UNITS:-4}"
        memory:
          size: ${AKASH_MEMORY:-16Gi}
        storage:
          - size: ${AKASH_STORAGE:-50Gi}
        gpu:
          units: 1
          attributes:
            vendor:
              nvidia:
                - model: ${AKASH_GPU_MODEL:-rtx4090}

  placement:
    akash:
      attributes:
        host: akash
      signedBy:
        anyOf:
          - "${AKASH_SIGNED_BY:-}"
      pricing:
        ollama:
          denom: uakt
          amount: ${AKASH_PRICE_UAKT:-50000}

deployment:
  ollama:
    akash:
      profile: ollama
      count: ${AKASH_DEPLOY_COUNT:-1}
