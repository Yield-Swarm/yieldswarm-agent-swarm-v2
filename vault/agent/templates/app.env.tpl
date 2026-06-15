{{- with secret "yieldswarm/data/azure" }}
AZURE_TENANT_ID={{ .Data.data.tenant_id }}
AZURE_SUBSCRIPTION_ID={{ .Data.data.subscription_id }}
AZURE_CLIENT_ID={{ .Data.data.client_id }}
AZURE_CLIENT_SECRET={{ .Data.data.client_secret }}
AZURE_RESOURCE_GROUP={{ .Data.data.resource_group }}
AZURE_LOCATION={{ .Data.data.location }}
{{- end }}

{{- with secret "yieldswarm/data/runpod" }}
RUNPOD_API_KEY={{ .Data.data.api_key }}
{{- end }}

{{- with secret "yieldswarm/data/vultr" }}
VULTR_API_KEY={{ .Data.data.api_key }}
{{- end }}

{{- with secret "yieldswarm/data/digitalocean" }}
DIGITALOCEAN_TOKEN={{ .Data.data.token }}
{{- end }}

{{- with secret "yieldswarm/data/rpc" }}
SOLANA_RPC_URL={{ .Data.data.solana_rpc_url }}
HELIUS_API_KEY={{ .Data.data.helius_api_key }}
FAILOVER_RPC_LIST={{ .Data.data.failover_rpc_list }}
{{- end }}

{{- with secret "yieldswarm/data/agents" }}
GROK_API_KEY={{ .Data.data.grok_api_key }}
OPENAI_API_KEY={{ .Data.data.openai_api_key }}
AGENTSWARM_MASTER_KEY={{ .Data.data.agentswarm_master_key }}
{{- end }}
