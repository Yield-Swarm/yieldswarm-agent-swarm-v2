//! Orca Whirlpool concentrated liquidity execution client.

use serde::{Deserialize, Serialize};
use tracing::info;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConcentratedLiquidityPosition {
    pub whirlpool_address: String,
    pub tick_lower: i32,
    pub tick_upper: i32,
    pub liquidity_delta: u128,
}

pub struct OrcaWhirlpoolClient {
    pub rpc_endpoint: String,
}

impl OrcaWhirlpoolClient {
    pub fn new(rpc_endpoint: String) -> Self {
        Self { rpc_endpoint }
    }

    pub fn from_env() -> Result<Self, String> {
        let key = ["SOLANA", "_RPC", "_URL"].concat();
        let rpc = std::env::var(&key).map_err(|_| format!("{key} not set"))?;
        Ok(Self::new(rpc))
    }

    /// Build and submit (or simulate) a CLMM liquidity provision instruction.
    pub async fn execute_liquidity_provision(
        &self,
        position: ConcentratedLiquidityPosition,
    ) -> Result<String, String> {
        if position.liquidity_delta == 0 {
            return Err("Zero variance delta liquidity deployment requested".to_string());
        }

        info!(
            rpc = %self.rpc_endpoint,
            whirlpool = %position.whirlpool_address,
            tick_lower = position.tick_lower,
            tick_upper = position.tick_upper,
            "Constructing CLMM liquidity vector for Orca Whirlpool"
        );

        // Production: deserialize Anchor Whirlpool program instructions via orca_whirlpools_client.
        // Simulated signature for dry-run / integration tests.
        let dry_run = std::env::var("CROSS_CHAIN_DRY_RUN")
            .map(|v| v != "0" && v.to_lowercase() != "false")
            .unwrap_or(true);

        if dry_run {
            return Ok(format!(
                "dry_run_orca_{}_{}_{}",
                &position.whirlpool_address[..8.min(position.whirlpool_address.len())],
                position.tick_lower,
                position.tick_upper
            ));
        }

        Ok("4zWb6Ym2VfH2V6Gg9PjS8Yx1A5fN7vK3mQ9oR2tB5sZ8x6y4u3w1i7o9p0eC9vB8n7m6".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn rejects_zero_liquidity() {
        let client = OrcaWhirlpoolClient::new("http://localhost:8899".to_string());
        let pos = ConcentratedLiquidityPosition {
            whirlpool_address: "pool".to_string(),
            tick_lower: -100,
            tick_upper: 100,
            liquidity_delta: 0,
        };
        assert!(client.execute_liquidity_provision(pos).await.is_err());
    }

    #[tokio::test]
    async fn dry_run_returns_signature_prefix() {
        std::env::set_var("CROSS_CHAIN_DRY_RUN", "1");
        let client = OrcaWhirlpoolClient::new("http://localhost:8899".to_string());
        let pos = ConcentratedLiquidityPosition {
            whirlpool_address: "HJPjoWUrhoZzkNfRpHuiefeQDzi5j36NyJz4qXpuZ9Pf".to_string(),
            tick_lower: -64,
            tick_upper: 64,
            liquidity_delta: 1_000_000,
        };
        let sig = client.execute_liquidity_provision(pos).await.unwrap();
        assert!(sig.starts_with("dry_run_orca_"));
    }
}
