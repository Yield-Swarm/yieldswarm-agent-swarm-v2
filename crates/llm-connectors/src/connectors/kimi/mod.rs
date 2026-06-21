use crate::connectors::http::post_json;
use serde::{Deserialize, Serialize};
use serde_json::json;

pub struct KimiClawConnector {
    endpoint_base: String,
    bearer_token: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ClawTaskConfig {
    pub task_name: String,
    pub cron_schedule: String,
    pub target_skill: String,
    pub runtime_instructions: String,
}

impl KimiClawConnector {
    pub fn new(bearer_token: String) -> Self {
        Self {
            endpoint_base: std::env::var("KIMI_CLAW_API_BASE")
                .unwrap_or_else(|_| "https://api.kimi.com/v1/claw".to_string()),
            bearer_token,
        }
    }

    pub fn from_env() -> Result<Self, String> {
        let bearer_token = std::env::var("KIMICLAW_CONSENSUS_KEY")
            .or_else(|_| std::env::var("KIMI_CLAW_API_TOKEN"))
            .map_err(|_| "KIMICLAW_CONSENSUS_KEY or KIMI_CLAW_API_TOKEN is not set".to_string())?;
        Ok(Self::new(bearer_token))
    }

    pub fn deploy_persistent_scheduled_task(&self, config: ClawTaskConfig) -> Result<String, String> {
        let endpoint = format!("{}/tasks/register", self.endpoint_base.trim_end_matches('/'));

        let payload = json!({
            "name": config.task_name,
            "schedule": config.cron_schedule,
            "skill_id": config.target_skill,
            "config": {
                "prompt_instructions": config.runtime_instructions,
                "persistence_strategy": "always_on",
                "output_target": "yield_swarm_ingest_pipeline"
            }
        });

        let auth = format!("Bearer {}", self.bearer_token);
        let response_json = post_json(
            &endpoint,
            &[
                ("Authorization", auth.as_str()),
                ("Content-Type", "application/json"),
            ],
            payload,
        )?;

        Ok(response_json.to_string())
    }
}
