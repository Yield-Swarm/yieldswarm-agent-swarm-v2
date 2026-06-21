//! Production environment — all secrets loaded from env / Vault injection.
//! Never hardcode API keys in source.

#[derive(Debug, Clone)]
pub struct EnvironmentConfig {
    pub agent_count_total: usize,
    pub agents_per_shard: usize,
    pub cron_shard_count: usize,
    pub infura_rpc_url: String,
    pub jupiter_api_key: String,
    pub azure_prod_location: String,
    pub azure_backup_location: String,
    pub azure_dr_location: String,
}

impl EnvironmentConfig {
    pub fn from_env() -> Self {
        Self {
            agent_count_total: parse_usize("AGENT_COUNT_TOTAL", 10_080),
            agents_per_shard: parse_usize("AGENTS_PER_SHARD", 84),
            cron_shard_count: parse_usize("CRON_SHARD_COUNT", 120),
            infura_rpc_url: std::env::var("INFURA_SOL_MAINNET_RPC")
                .or_else(|_| std::env::var("SOLANA_RPC_URL"))
                .or_else(|_| std::env::var("QUICKNODE_RPC_URL"))
                .unwrap_or_default(),
            jupiter_api_key: std::env::var("JUPITER_API_KEY").unwrap_or_default(),
            azure_prod_location: std::env::var("AZURE_PROD_LOCATION")
                .unwrap_or_else(|_| "Australia East".to_string()),
            azure_backup_location: std::env::var("AZURE_BACKUP_LOCATION")
                .unwrap_or_else(|_| "Japan East".to_string()),
            azure_dr_location: std::env::var("AZURE_DR_LOCATION")
                .unwrap_or_else(|_| "Indonesia Central".to_string()),
        }
    }

    pub fn validate_production(&self) -> Vec<String> {
        let mut warnings = Vec::new();
        if self.infura_rpc_url.is_empty() {
            warnings.push("INFURA_SOL_MAINNET_RPC or SOLANA_RPC_URL not set".to_string());
        }
        if self.jupiter_api_key.is_empty() {
            warnings.push("JUPITER_API_KEY not set".to_string());
        }
        let expected = self.cron_shard_count * self.agents_per_shard;
        if expected != self.agent_count_total {
            warnings.push(format!(
                "Shard math mismatch: {} shards × {} agents = {} (expected AGENT_COUNT_TOTAL {})",
                self.cron_shard_count,
                self.agents_per_shard,
                expected,
                self.agent_count_total
            ));
        }
        warnings
    }
}

fn parse_usize(key: &str, default: usize) -> usize {
    std::env::var(key)
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(default)
}
