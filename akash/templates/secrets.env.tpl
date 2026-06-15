# Runtime secrets — rendered by Vault Agent from KV v2.
# Do not edit manually; values come from yieldswarm/agents/runtime.

{{- with secret "yieldswarm/data/agents/runtime" }}
AGENTSWARM_MASTER_KEY={{ .Data.data.agentswarm_master_key }}
KIMICLAW_CONSENSUS_KEY={{ .Data.data.kimiclaw_consensus_key }}
GROK_API_KEY={{ .Data.data.grok_api_key }}
OPENAI_API_KEY={{ .Data.data.openai_api_key }}
GEMINI_API_KEY={{ .Data.data.gemini_api_key }}
ANTHROPIC_API_KEY={{ .Data.data.anthropic_api_key }}
WALLET_ENCRYPTION_KEY={{ .Data.data.wallet_encryption_key }}
TEE_SIGNING_KEY={{ .Data.data.tee_signing_key }}
DATABASE_ENCRYPTION_KEY={{ .Data.data.database_encryption_key }}
GPU_CLUSTER_KEYS={{ .Data.data.gpu_cluster_keys }}
AGENT_SHARD_ID={{ .Data.data.agent_shard_id }}
AGENT_COUNT_TOTAL={{ .Data.data.agent_count_total }}
AGENTS_PER_SHARD={{ .Data.data.agents_per_shard }}
{{- end }}

{{- with secret "yieldswarm/data/runpod" }}
RUNPOD_API_KEY={{ .Data.data.api_key }}
RUNPOD_ENDPOINT={{ .Data.data.endpoint }}
{{- end }}
