{{- /* Vault Agent template — renders KV secrets to a sourced env file */ -}}
{{- with secret "yieldswarm/data/akash" -}}
AKASH_AUTH_METHOD={{ .Data.data.auth_method }}
AKASH_KEY_NAME={{ .Data.data.key_name }}
AKASH_KEYRING_BACKEND={{ .Data.data.keyring_backend }}
AKASH_WALLET_MNEMONIC={{ .Data.data.wallet_mnemonic }}
AKASH_ACCOUNT_ADDRESS={{ .Data.data.account_address }}
AKASH_JWT={{ .Data.data.provider_jwt }}
AKASH_CONSOLE_API_KEY={{ .Data.data.console_api_key }}
AKASH_CERTIFICATE_PATH={{ .Data.data.certificate_path }}
AKASH_KEY_PATH={{ .Data.data.key_path }}
AKASH_RPC_ENDPOINT={{ .Data.data.rpc_endpoint }}
AKASH_CHAIN_ID={{ .Data.data.chain_id }}
AKASH_GAS_PRICES={{ .Data.data.gas_prices }}
AGENTSWARM_MASTER_KEY={{ .Data.data.agentswarm_master_key }}
GPU_CLUSTER_KEYS={{ .Data.data.gpu_cluster_keys }}
{{- end }}
{{- with secret "yieldswarm/data/rpc" -}}
SOLANA_RPC_URL={{ .Data.data.solana_rpc_url }}
HELIUS_API_KEY={{ .Data.data.helius_api_key }}
FAILOVER_RPC_LIST={{ .Data.data.failover_rpc_list }}
BIRDEYE_API_KEY={{ .Data.data.birdeye_api_key }}
JUPITER_API_KEY={{ .Data.data.jupiter_api_key }}
RAYDIUM_API_KEY={{ .Data.data.raydium_api_key }}
{{- end }}
{{- with secret "yieldswarm/data/runpod" -}}
RUNPOD_API_KEY={{ .Data.data.api_key }}
{{- end }}
