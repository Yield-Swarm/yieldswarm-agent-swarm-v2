//! Swarm OS orchestrator — Prompts 1, 36, 43.

mod apollo;
mod elevator;
mod elizaos;

pub use apollo::ApolloNexus;
pub use elevator::{ElevatorLaneResult, ElevatorScheduler, ELEVATOR_COUNT};
pub use elizaos::{ElizaAgentTurn, ElizaOsBridge, NoopElizaBridge};

use crate::registry::{AgentProfile, ShardedAgentRegistry};
use crate::SwarmMessage;
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::{debug, info};

/// Async message bus orchestrator for 50+ concurrent LLM agent instances.
pub struct SwarmOrchestrator {
    registry: Arc<ShardedAgentRegistry>,
    tx_bus: mpsc::Sender<SwarmMessage>,
    eliza: Arc<dyn ElizaOsBridge>,
}

impl SwarmOrchestrator {
    pub fn new(
        registry: Arc<ShardedAgentRegistry>,
        buffer_capacity: usize,
        eliza: Arc<dyn ElizaOsBridge>,
    ) -> (Self, mpsc::Receiver<SwarmMessage>) {
        let (tx_bus, rx_bus) = mpsc::channel(buffer_capacity);
        (
            Self {
                registry,
                tx_bus,
                eliza,
            },
            rx_bus,
        )
    }

    pub fn sender(&self) -> mpsc::Sender<SwarmMessage> {
        self.tx_bus.clone()
    }

    pub async fn dispatch_message(
        &self,
        message: SwarmMessage,
    ) -> Result<(), mpsc::error::SendError<SwarmMessage>> {
        self.tx_bus.send(message).await
    }

    /// Main orchestration loop — spawns per-message tasks (14-elevator model).
    pub async fn run_orchestration_loop(
        registry: Arc<ShardedAgentRegistry>,
        eliza: Arc<dyn ElizaOsBridge>,
        mut rx_bus: mpsc::Receiver<SwarmMessage>,
    ) {
        info!("Swarm OS orchestration runtime started");

        while let Some(message) = rx_bus.recv().await {
            let registry = Arc::clone(&registry);
            let eliza = Arc::clone(&eliza);

            tokio::spawn(async move {
                info!("Routing message {}", message.id);
                if let Some(target) = &message.target_agent {
                    if let Some(profile) = registry.get_agent(target) {
                        execute_agent_turn(&eliza, profile, message).await;
                    }
                } else {
                    let subscribers = registry.list_by_capability("broadcast_listener");
                    for agent in subscribers {
                        execute_agent_turn(&eliza, agent, message.clone()).await;
                    }
                }
            });
        }
    }
}

async fn execute_agent_turn(
    eliza: &Arc<dyn ElizaOsBridge>,
    profile: AgentProfile,
    msg: SwarmMessage,
) {
    debug!("Agent {} executing turn", profile.agent_id);
    let turn = ElizaAgentTurn {
        agent_id: profile.agent_id.clone(),
        character_id: profile.eliza_character_id.clone(),
        message_id: msg.id.clone(),
        payload: msg.payload.clone(),
    };
    if let Err(e) = eliza.execute_turn(turn).await {
        tracing::warn!("ElizaOS turn failed for {}: {}", profile.agent_id, e);
    }
}
