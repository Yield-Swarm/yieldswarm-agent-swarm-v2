# RPC secrets — rendered by Vault Agent from yieldswarm/rpc.

{{- with secret "yieldswarm/data/rpc" }}
SOLANA_RPC_URL={{ .Data.data.solana_rpc_url }}
HELIUS_API_KEY={{ .Data.data.helius_api_key }}
FAILOVER_RPC_LIST={{ .Data.data.failover_rpc_list }}
BIRDEYE_API_KEY={{ .Data.data.birdeye_api_key }}
JUPITER_API_KEY={{ .Data.data.jupiter_api_key }}
{{- end }}
