use crate::connectors::http::post_json;
use serde::{Deserialize, Serialize};
use serde_json::json;

pub struct SuperGrokConnector {
    api_token: String,
    model: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GrokResponse {
    pub choices: Vec<GrokChoice>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GrokChoice {
    pub message: GrokMessage,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct GrokMessage {
    pub content: String,
}

impl SuperGrokConnector {
    pub fn new(api_token: String) -> Self {
        Self {
            api_token,
            model: std::env::var("GROK_MODEL").unwrap_or_else(|_| "grok-2-latest".to_string()),
        }
    }

    pub fn from_env() -> Result<Self, String> {
        let api_token = std::env::var("GROK_API_KEY")
            .or_else(|_| std::env::var("XAI_API_KEY"))
            .map_err(|_| "GROK_API_KEY or XAI_API_KEY is not set".to_string())?;
        Ok(Self::new(api_token))
    }

    pub fn query_realtime_market_intel(&self, analytical_query: &str) -> Result<String, String> {
        let url = std::env::var("GROK_API_BASE")
            .unwrap_or_else(|_| "https://api.x.ai/v1/chat/completions".to_string());

        let payload = json!({
            "model": self.model,
            "messages": [
                {
                    "role": "system",
                    "content": "You are the YieldSwarm real-time intelligence node. Analyze live web and X context metrics. Cite uncertainty when data is stale."
                },
                {
                    "role": "user",
                    "content": analytical_query
                }
            ],
            "temperature": 0.1
        });

        let auth = format!("Bearer {}", self.api_token);
        let response_json = post_json(
            &url,
            &[
                ("Authorization", auth.as_str()),
                ("Content-Type", "application/json"),
            ],
            payload,
        )?;

        let grok_raw: GrokResponse = serde_json::from_value(response_json)
            .map_err(|e| format!("SuperGrok parse error: {}", e))?;

        if grok_raw.choices.is_empty() {
            return Err("SuperGrok returned an empty completion array".to_string());
        }

        Ok(grok_raw.choices[0].message.content.clone())
    }
}
