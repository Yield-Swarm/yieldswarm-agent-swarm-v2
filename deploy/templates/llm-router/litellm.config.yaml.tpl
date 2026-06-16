# LiteLLM router — env-driven model list
# Mount as /app/config.yaml in ghcr.io/yieldswarm/litellm-router
model_list:
  - model_name: ${LLM__DEFAULT_MODEL:-llama3.1:8b}
    litellm_params:
      model: ollama/${AKASH_OLLAMA_MODEL:-llama3.1:8b}
      api_base: ${AKASH_OLLAMA_BASE_URL}
      api_key: ${YIELDSWARM_ROUTER_API_KEY}
  - model_name: openai-gpt4
    litellm_params:
      model: gpt-4o
      api_key: ${OPENAI_API_KEY}
  - model_name: anthropic-sonnet
    litellm_params:
      model: ${OPENROUTER_MODEL}
      api_key: ${OPENROUTER_API_KEY}
  - model_name: fireworks-70b
    litellm_params:
      model: ${FIREWORKS_MODEL}
      api_key: ${FIREWORKS_API_KEY}

general_settings:
  master_key: ${YIELDSWARM_ROUTER_API_KEY}

router_settings:
  routing_strategy: simple-shuffle
