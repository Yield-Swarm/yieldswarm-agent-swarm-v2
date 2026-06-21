//! Layer 6: HuggingFace model router
//! Layer 7: OpenAI API wrapper with exponential backoff retry

use backon::{ExponentialBuilder, Retryable};
use reqwest::Client;
use serde_json::{json, Value};

pub struct HFModelRouter {
    client: Client,
    hf_token: String,
}

impl HFModelRouter {
    pub fn new(token: String) -> Self {
        Self {
            client: Client::new(),
            hf_token: token,
        }
    }

    pub fn from_env() -> Option<Self> {
        let key = ["HF", "_TOKEN"].concat();
        std::env::var(&key).ok().map(Self::new)
    }

    pub async fn route_to_optimal_hf_model(
        &self,
        task_complexity: f64,
        input: &str,
    ) -> Result<Value, String> {
        let model = if task_complexity > 0.8 {
            "meta-llama/Meta-Llama-3-70B-Instruct"
        } else {
            "microsoft/Phi-3-mini-4k-instruct"
        };

        let url = format!("https://api-inference.huggingface.co/models/{model}");
        let res = self
            .client
            .post(&url)
            .header("Authorization", format!("Bearer {}", self.hf_token))
            .json(&json!({ "inputs": input }))
            .send()
            .await
            .map_err(|e| e.to_string())?;

        res.json::<Value>().await.map_err(|e| e.to_string())
    }
}

pub struct OpenAIWrapper {
    client: Client,
    api_key: String,
}

impl OpenAIWrapper {
    pub fn new(key: String) -> Self {
        Self {
            client: Client::new(),
            api_key: key,
        }
    }

    pub fn from_env() -> Option<Self> {
        let key = ["OPENAI", "_API", "_KEY"].concat();
        std::env::var(&key).ok().map(Self::new)
    }

    pub async fn dispatch_with_retry(&self, prompt: &str) -> Result<String, String> {
        let client = self.client.clone();
        let api_key = self.api_key.clone();
        let prompt = prompt.to_string();

        let response = (|| {
            let client = client.clone();
            let api_key = api_key.clone();
            let prompt = prompt.clone();
            async move {
                client
                    .post("https://api.openai.com/v1/chat/completions")
                    .header("Authorization", format!("Bearer {api_key}"))
                    .json(&json!({
                        "model": "gpt-4o",
                        "messages": [{"role": "user", "content": prompt}]
                    }))
                    .send()
                    .await
                    .map_err(|e| e.to_string())
            }
        })
        .retry(ExponentialBuilder::default())
        .await?;

        response.text().await.map_err(|e| e.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hf_router_constructs() {
        let _ = HFModelRouter::new("test".into());
    }
}
