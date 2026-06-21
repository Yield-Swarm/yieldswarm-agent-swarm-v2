//! Layer 3: Multi-LLM API connectors
//! Layer 8: Kimi Klaw · Layer 10: SuperGrok · Layer 11: Gemini · Layer 12: Iclash

use reqwest::Client;
use serde_json::{json, Value};

pub struct CoreMultiLLMConnector {
    client: Client,
}

impl CoreMultiLLMConnector {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
        }
    }

    pub async fn execute_gemini_structured(
        &self,
        api_key: &str,
        prompt: &str,
    ) -> Result<Value, String> {
        let url = format!(
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key={api_key}"
        );
        let response = self
            .client
            .post(&url)
            .json(&json!({
                "contents": [{ "parts": [{ "text": prompt }] }],
                "generationConfig": { "responseMimeType": "application/json" }
            }))
            .send()
            .await
            .map_err(|e| e.to_string())?;
        response.json::<Value>().await.map_err(|e| e.to_string())
    }

    pub async fn execute_super_grok(&self, api_key: &str, query: &str) -> Result<Value, String> {
        let url = "https://api.x.ai/v1/chat/completions";
        let response = self
            .client
            .post(url)
            .header("Authorization", format!("Bearer {api_key}"))
            .json(&json!({
                "model": "grok-2-latest",
                "messages": [{"role": "user", "content": query}]
            }))
            .send()
            .await
            .map_err(|e| e.to_string())?;
        response.json::<Value>().await.map_err(|e| e.to_string())
    }

    pub async fn execute_kimi_klaw(&self, endpoint: &str, payload: Value) -> Result<Value, String> {
        let response = self
            .client
            .post(endpoint)
            .json(&payload)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        response.json::<Value>().await.map_err(|e| e.to_string())
    }

    pub async fn query_iclash_context(&self, target_node: &str) -> Result<Value, String> {
        let url = format!("https://api.iclash.net/v1/context/{target_node}");
        let response = self
            .client
            .get(&url)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        response.json::<Value>().await.map_err(|e| e.to_string())
    }

    pub async fn execute_haji_cloud(&self, endpoint: &str, token: &str, body: Value) -> Result<Value, String> {
        let response = self
            .client
            .post(endpoint)
            .header("Authorization", format!("Bearer {token}"))
            .json(&body)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        response.json::<Value>().await.map_err(|e| e.to_string())
    }
}

impl Default for CoreMultiLLMConnector {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn connector_instantiates() {
        let _ = CoreMultiLLMConnector::new();
    }
}
