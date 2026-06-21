//! Layer 1: Rust core Swarm OS orchestrator (50+ LLM instances)
//! Layer 4: Sharded agent registry (10,000+ agents)
//! Layer 5: ElizaOS integration runtime context

mod connectors;
mod router;

use std::sync::Arc;

use dashmap::DashMap;
use tokio::sync::mpsc;
use tracing::info;

pub use connectors::CoreMultiLLMConnector;
pub use router::{HFModelRouter, OpenAIWrapper};

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
pub struct AgentState {
    pub agent_id: String,
    pub target_llm: String,
    pub eliza_runtime_context: serde_json::Value,
}

pub struct ShardedAgentRegistry {
    pub shards: Arc<DashMap<String, AgentState>>,
}

impl ShardedAgentRegistry {
    pub fn new() -> Self {
        Self {
            shards: Arc::new(DashMap::with_shard_amount(64)),
        }
    }

    pub fn count(&self) -> usize {
        self.shards.len()
    }
}

impl Default for ShardedAgentRegistry {
    fn default() -> Self {
        Self::new()
    }
}

pub struct SwarmOSOrchestrator {
    registry: ShardedAgentRegistry,
    message_bus_tx: mpsc::Sender<String>,
}

impl SwarmOSOrchestrator {
    pub fn new(tx: mpsc::Sender<String>) -> Self {
        Self {
            registry: ShardedAgentRegistry::new(),
            message_bus_tx: tx,
        }
    }

    pub fn registry(&self) -> &ShardedAgentRegistry {
        &self.registry
    }

    pub async fn boot_eliza_runtime_node(&self, agent_id: &str, provider: &str) {
        let initial_state = AgentState {
            agent_id: agent_id.to_string(),
            target_llm: provider.to_string(),
            eliza_runtime_context: serde_json::json!({
                "eliza_version": "1.0.0-rust-layer",
                "memory_kv_locked": false
            }),
        };
        self.registry
            .shards
            .insert(agent_id.to_string(), initial_state);
        let _ = self
            .message_bus_tx
            .send(format!("eliza_boot:{agent_id}:{provider}"))
            .await;
    }
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    let (tx, mut rx) = mpsc::channel::<String>(1000);

    tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            tracing::debug!(%msg, "swarm message bus");
        }
    });

    let orchestrator = SwarmOSOrchestrator::new(tx);

    orchestrator
        .boot_eliza_runtime_node("agent_01_alpha", "SuperGrok")
        .await;

    info!(
        agents = orchestrator.registry().count(),
        "Swarm Core OS Orchestrator active"
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn registry_boots_agent() {
        let (tx, _rx) = mpsc::channel(8);
        let orch = SwarmOSOrchestrator::new(tx);
        orch.boot_eliza_runtime_node("test_agent", "OpenAI").await;
        assert_eq!(orch.registry().count(), 1);
    }
}
