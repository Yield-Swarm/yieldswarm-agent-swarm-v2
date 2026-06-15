pid_file = "/tmp/vault-agent.pid"

vault {
  # VAULT_ADDR and VAULT_NAMESPACE from the Akash environment override this
  # non-secret placeholder at runtime.
  address = "https://vault.example.com"
}

auto_auth {
  method "approle" {
    mount_path = "auth/approle"

    config = {
      role_id_file_path   = "/vault/auth/role_id"
      secret_id_file_path = "/vault/auth/secret_id"
      remove_secret_id_file_after_reading = true
    }
  }

  sink "file" {
    config = {
      path = "/vault/token/.vault-token"
      mode = 0400
    }
  }
}

cache {
  use_auto_auth_token = true
}

template {
  destination = "/vault/secrets/yieldswarm.json"
  perms       = 0400
  error_on_missing_key = true

  contents = <<EOT
{{ with secret "secret/data/yieldswarm/core" }}{{ $core := .Data.data }}{{ with secret "secret/data/yieldswarm/llm" }}{{ $llm := .Data.data }}{{ with secret "secret/data/yieldswarm/rpc" }}{{ $rpc := .Data.data }}{{ with secret "secret/data/yieldswarm/cloud/runpod" }}{{ $runpod := .Data.data }}{{ with secret "secret/data/yieldswarm/cloud/vultr" }}{{ $vultr := .Data.data }}{{ with secret "secret/data/yieldswarm/cloud/digitalocean" }}{{ $do := .Data.data }}{{ with secret "secret/data/yieldswarm/depin/akash" }}{{ $akash := .Data.data }}{{ with secret "secret/data/yieldswarm/blockchain/signing" }}{{ $signing := .Data.data }}
{
  "AGENTSWARM_MASTER_KEY": {{ index $core "AGENTSWARM_MASTER_KEY" | toJSON }},
  "KIMICLAW_CONSENSUS_KEY": {{ index $core "KIMICLAW_CONSENSUS_KEY" | toJSON }},
  "GROK_API_KEY": {{ index $llm "GROK_API_KEY" | toJSON }},
  "OPENAI_API_KEY": {{ index $llm "OPENAI_API_KEY" | toJSON }},
  "GEMINI_API_KEY": {{ index $llm "GEMINI_API_KEY" | toJSON }},
  "ANTHROPIC_API_KEY": {{ index $llm "ANTHROPIC_API_KEY" | toJSON }},
  "PRIMARY_RPC_URL": {{ index $rpc "primary_rpc_url" | toJSON }},
  "SOLANA_RPC_URL": {{ index $rpc "solana_rpc_url" | toJSON }},
  "ETHEREUM_RPC_URL": {{ index $rpc "ethereum_rpc_url" | toJSON }},
  "POLYGON_RPC_URL": {{ index $rpc "polygon_rpc_url" | toJSON }},
  "HELIUS_API_KEY": {{ index $rpc "helius_api_key" | toJSON }},
  "RUNPOD_API_KEY": {{ index $runpod "api_key" | toJSON }},
  "RUNPOD_ENDPOINT_ID": {{ index $runpod "endpoint_id" | toJSON }},
  "VULTR_API_KEY": {{ index $vultr "api_key" | toJSON }},
  "VULTR_REGION": {{ index $vultr "region" | toJSON }},
  "DIGITALOCEAN_TOKEN": {{ index $do "token" | toJSON }},
  "DIGITALOCEAN_REGION": {{ index $do "region" | toJSON }},
  "AKASH_KEY_NAME": {{ index $akash "key_name" | toJSON }},
  "AKASH_WALLET_ADDRESS": {{ index $akash "wallet_address" | toJSON }},
  "AKASH_MNEMONIC": {{ index $akash "mnemonic" | toJSON }},
  "AKASH_NET": {{ index $akash "net" | toJSON }},
  "AKASH_CHAIN_ID": {{ index $akash "chain_id" | toJSON }},
  "AKASH_NODE": {{ index $akash "node" | toJSON }},
  "WALLET_ENCRYPTION_KEY": {{ index $signing "wallet_encryption_key" | toJSON }},
  "TEE_SIGNING_KEY": {{ index $signing "tee_signing_key" | toJSON }},
  "CHAINLINK_VAULT_ADDRESS": {{ index $signing "chainlink_vault_address" | toJSON }}
}
{{ end }}{{ end }}{{ end }}{{ end }}{{ end }}{{ end }}{{ end }}{{ end }}
EOT
}
