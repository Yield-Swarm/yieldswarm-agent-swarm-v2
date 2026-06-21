//! Apollo Nexus orchestration core — Prompt 43.
//!
//! Unifies registry, 14-elevator scheduler, council governance, and YSLR parsing.

use crate::governance::{CouncilDecision, CouncilEngine, CouncilVote, VoteOutcome};
use crate::orchestrator::elevator::{ElevatorLaneResult, ElevatorScheduler};
use crate::orchestrator::elizaos::{ElizaOsBridge, NoopElizaBridge};
use crate::orchestrator::SwarmOrchestrator;
use crate::parser::{parse_yslr, YslrDocument};
use crate::registry::ShardedAgentRegistry;
use crate::SwarmMessage;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::info;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NexusDispatchResult {
    pub message_id: String,
    pub yslr: Option<YslrDocument>,
    pub elevator_results: Vec<ElevatorLaneResult>,
    pub council: Option<CouncilDecision>,
}

/// Top-level orchestration facade for Phase 1 runtime.
pub struct ApolloNexus {
    registry: Arc<ShardedAgentRegistry>,
    council: CouncilEngine,
    eliza: Arc<dyn ElizaOsBridge>,
    tx: mpsc::Sender<SwarmMessage>,
}

impl ApolloNexus {
    pub fn bootstrap(buffer_capacity: usize) -> (Self, mpsc::Receiver<SwarmMessage>) {
        let registry = Arc::new(ShardedAgentRegistry::new());
        let eliza: Arc<dyn ElizaOsBridge> = Arc::new(NoopElizaBridge);
        let (orch, rx) = SwarmOrchestrator::new(
            Arc::clone(&registry),
            buffer_capacity,
            Arc::clone(&eliza),
        );
        let nexus = Self {
            registry,
            council: CouncilEngine::helix_default(),
            eliza,
            tx: orch.sender(),
        };
        (nexus, rx)
    }

    pub fn registry(&self) -> &Arc<ShardedAgentRegistry> {
        &self.registry
    }

    pub fn council(&self) -> &CouncilEngine {
        &self.council
    }

    pub async fn dispatch(&self, message: SwarmMessage) -> Result<(), mpsc::error::SendError<SwarmMessage>> {
        self.tx.send(message).await
    }

    /// Parse YSLR payload, run 14-elevator matrix, optional council gate.
    pub async fn dispatch_yslr_frame(&self, raw: &str) -> Result<NexusDispatchResult, String> {
        let yslr = parse_yslr(raw).map_err(|e| e.to_string())?;
        let message = SwarmMessage {
            id: crate::id::new_id("yslr"),
            source_agent: "apollo-nexus".into(),
            target_agent: None,
            elevator_lane: yslr.lane.parse().ok(),
            payload: yslr.payload.clone(),
            timestamp: crate::unix_now(),
        };

        let lane = yslr.lane.clone();
        let handler = Arc::new(move |elev: u8, msg: SwarmMessage| {
            let lane = lane.clone();
            async move { format!("lane={elev} yslr_lane={lane} msg={}", msg.id) }
        });

        let elevator_results = ElevatorScheduler::dispatch_parallel(message.clone(), handler).await;

        let council = self.council.decide(
            &message.id,
            &(1..=9)
                .map(|i| CouncilVote {
                    member_id: format!("council-{:02}", i),
                    outcome: VoteOutcome::Approve,
                })
                .collect::<Vec<_>>(),
        );

        self.dispatch(message.clone()).await.map_err(|e| e.to_string())?;

        info!("Apollo Nexus dispatched YSLR frame route={}", yslr.route);

        Ok(NexusDispatchResult {
            message_id: message.id,
            yslr: Some(yslr),
            elevator_results,
            council: Some(council),
        })
    }

    pub fn spawn_runtime(&self, rx: mpsc::Receiver<SwarmMessage>) -> tokio::task::JoinHandle<()> {
        let registry = Arc::clone(&self.registry);
        let eliza = Arc::clone(&self.eliza);
        tokio::spawn(async move {
            SwarmOrchestrator::run_orchestration_loop(registry, eliza, rx).await;
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn yslr_dispatch_produces_elevator_results() {
        let (nexus, _rx) = ApolloNexus::bootstrap(64);
        let result = nexus
            .dispatch_yslr_frame("YSLR lane=7 route=helix payload={\"op\":\"test\"}")
            .await
            .unwrap();
        assert_eq!(result.elevator_results.len(), 14);
        assert!(result.council.unwrap().approved);
    }
}
