use crate::connectors::http::post_json;
use serde::{Deserialize, Serialize};
use serde_json::json;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct YieldStrategy {
    pub protocol: String,
    pub token_pair: String,
    pub target_allocation_pct: f64,
    pub logic_justification: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct StructuredYieldResponse {
    pub batch_id: String,
    pub strategies: Vec<YieldStrategy>,
    pub execution_risk_score: u8,
}

pub struct GeminiConnector {
    api_key: String,
    model: String,
    max_retries: u8,
}

impl GeminiConnector {
    pub fn new(api_key: String) -> Self {
        Self {
            api_key,
            model: std::env::var("GEMINI_MODEL")
                .unwrap_or_else(|_| "gemini-2.5-pro".to_string()),
            max_retries: 2,
        }
    }

    pub fn from_env() -> Result<Self, String> {
        let api_key = std::env::var("GEMINI_API_KEY")
            .map_err(|_| "GEMINI_API_KEY is not set".to_string())?;
        Ok(Self::new(api_key))
    }

    pub fn fetch_structured_strategy(
        &self,
        prompt: &str,
    ) -> Result<StructuredYieldResponse, String> {
        let mut last_err = String::new();
        let mut correction_hint: Option<String> = None;

        for attempt in 0..=self.max_retries {
            match self.request_structured(prompt, correction_hint.as_deref()) {
                Ok(data) => return Ok(data),
                Err(err) => {
                    last_err = err.clone();
                    if attempt < self.max_retries {
                        correction_hint = Some(format!(
                            "Previous response failed validation: {}. Return ONLY valid JSON matching the schema.",
                            err
                        ));
                    }
                }
            }
        }

        Err(last_err)
    }

    fn request_structured(
        &self,
        prompt: &str,
        correction_hint: Option<&str>,
    ) -> Result<StructuredYieldResponse, String> {
        let url = format!(
            "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent?key={}",
            self.model, self.api_key
        );

        let user_text = match correction_hint {
            Some(hint) => format!("{}\n\n{}", prompt, hint),
            None => prompt.to_string(),
        };

        let payload = json!({
            "contents": [{ "parts": [{ "text": user_text }] }],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": {
                    "type": "OBJECT",
                    "properties": {
                        "batch_id": { "type": "STRING" },
                        "execution_risk_score": { "type": "INTEGER" },
                        "strategies": {
                            "type": "ARRAY",
                            "items": {
                                "type": "OBJECT",
                                "properties": {
                                    "protocol": { "type": "STRING" },
                                    "token_pair": { "type": "STRING" },
                                    "target_allocation_pct": { "type": "NUMBER" },
                                    "logic_justification": { "type": "STRING" }
                                },
                                "required": ["protocol", "token_pair", "target_allocation_pct", "logic_justification"]
                            }
                        }
                    },
                    "required": ["batch_id", "strategies", "execution_risk_score"]
                }
            }
        });

        let response_json = post_json(&url, &[], payload)?;

        let text_content = response_json["candidates"][0]["content"]["parts"][0]["text"]
            .as_str()
            .ok_or("Failed to extract valid text from Gemini response payload")?;

        serde_json::from_str::<StructuredYieldResponse>(text_content)
            .map_err(|e| format!("Schema validation error parsing structural data: {}", e))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_valid_yield_json() {
        let raw = r#"{
            "batch_id": "batch-001",
            "execution_risk_score": 4,
            "strategies": [{
                "protocol": "jito",
                "token_pair": "SOL/USDC",
                "target_allocation_pct": 25.5,
                "logic_justification": "stable spread"
            }]
        }"#;
        let parsed: StructuredYieldResponse = serde_json::from_str(raw).unwrap();
        assert_eq!(parsed.batch_id, "batch-001");
        assert_eq!(parsed.strategies.len(), 1);
    }
}
