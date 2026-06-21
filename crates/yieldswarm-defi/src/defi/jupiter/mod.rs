//! Jupiter V6 quote discovery and swap transaction build.

use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

const DEFAULT_JUPITER_BASE: &str = "https://quote-api.jup.ag/v6";

/// Normalized swap quote exposed to the swarm engine.
#[derive(Debug, Deserialize, Serialize, Clone)]
pub struct SwapQuote {
    pub in_amount: String,
    pub out_amount: String,
    pub price_impact_pct: f64,
    pub route_plan: Value,
    pub swap_transaction: Option<String>,
}

pub struct JupiterRouteWrapper {
    client: Client,
    api_base: String,
    api_key: Option<String>,
}

impl Default for JupiterRouteWrapper {
    fn default() -> Self {
        Self::new()
    }
}

impl JupiterRouteWrapper {
    pub fn new() -> Self {
        let api_base = std::env::var(["JUPITER", "_API", "_URL"].concat())
            .unwrap_or_else(|_| DEFAULT_JUPITER_BASE.to_string())
            .trim_end_matches('/')
            .to_string();
        let api_key = std::env::var(["JUPITER", "_API", "_KEY"].concat())
            .ok()
            .filter(|k| !k.is_empty());

        Self {
            client: Client::new(),
            api_base,
            api_key,
        }
    }

    pub fn with_api_base(api_base: impl Into<String>) -> Self {
        let mut s = Self::new();
        s.api_base = api_base.into().trim_end_matches('/').to_string();
        s
    }

    fn apply_api_key(&self, req: reqwest::RequestBuilder) -> reqwest::RequestBuilder {
        if let Some(ref key) = self.api_key {
            req.header("x-api-key", key)
        } else {
            req
        }
    }

    /// Fetch optimal quote and optionally build serialized swap transaction.
    pub async fn fetch_optimal_quote(
        &self,
        input_mint: &str,
        output_mint: &str,
        amount: u64,
        slippage_bps: u32,
        user_public_key: Option<&str>,
    ) -> Result<SwapQuote, String> {
        let url = format!("{}/quote", self.api_base);
        let query = [
            ("inputMint", input_mint),
            ("outputMint", output_mint),
            ("amount", &amount.to_string()),
            ("slippageBps", &slippage_bps.to_string()),
            ("onlyDirectRoutes", "false"),
        ];

        let response = self
            .apply_api_key(self.client.get(&url))
            .query(&query)
            .send()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(format!("Jupiter quote HTTP {status}: {body}"));
        }

        let raw: Value = response.json().await.map_err(|e| e.to_string())?;

        let mut quote = SwapQuote {
            in_amount: raw
                .get("inAmount")
                .and_then(|v| v.as_str())
                .unwrap_or(&amount.to_string())
                .to_string(),
            out_amount: raw
                .get("outAmount")
                .and_then(|v| v.as_str())
                .unwrap_or("0")
                .to_string(),
            price_impact_pct: raw
                .get("priceImpactPct")
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0),
            route_plan: raw.get("routePlan").cloned().unwrap_or(json!([])),
            swap_transaction: None,
        };

        if let Some(pubkey) = user_public_key {
            let swap_tx = self.build_swap_transaction(&raw, pubkey).await?;
            quote.swap_transaction = Some(swap_tx);
        }

        Ok(quote)
    }

    async fn build_swap_transaction(
        &self,
        quote_response: &Value,
        user_public_key: &str,
    ) -> Result<String, String> {
        let url = format!("{}/swap", self.api_base);
        let payload = json!({
            "quoteResponse": quote_response,
            "userPublicKey": user_public_key,
            "wrapAndUnwrapSol": true,
            "computeUnitPriceMicroLamports": 50_000u64
        });

        let response = self
            .apply_api_key(self.client.post(&url))
            .json(&payload)
            .send()
            .await
            .map_err(|e| e.to_string())?;

        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().await.unwrap_or_default();
            return Err(format!("Jupiter swap HTTP {status}: {body}"));
        }

        let res_json: Value = response.json().await.map_err(|e| e.to_string())?;

        res_json
            .get("swapTransaction")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .ok_or_else(|| "Failed to extract serialized base64 transaction string".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wrapper_uses_default_jupiter_base() {
        let w = JupiterRouteWrapper::new();
        assert!(w.api_base.contains("jup.ag"));
    }
}
