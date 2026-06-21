//! ElizaOS integration layer — Prompt 5.

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ElizaAgentTurn {
    pub agent_id: String,
    pub character_id: Option<String>,
    pub message_id: String,
    pub payload: String,
}

#[derive(Debug, Error)]
pub enum ElizaError {
    #[error("agent not configured: {0}")]
    NotConfigured(String),
    #[error("runtime error: {0}")]
    Runtime(String),
}

/// Bridge to ElizaOS agent runtime (HTTP/IPC implementation supplied by host).
#[async_trait]
pub trait ElizaOsBridge: Send + Sync {
    async fn execute_turn(&self, turn: ElizaAgentTurn) -> Result<(), ElizaError>;
}

/// Default no-op bridge for tests and dry-run orchestration.
pub struct NoopElizaBridge;

#[async_trait]
impl ElizaOsBridge for NoopElizaBridge {
    async fn execute_turn(&self, turn: ElizaAgentTurn) -> Result<(), ElizaError> {
        tracing::debug!(
            "ElizaOS noop turn agent={} msg={}",
            turn.agent_id,
            turn.message_id
        );
        Ok(())
    }
}
