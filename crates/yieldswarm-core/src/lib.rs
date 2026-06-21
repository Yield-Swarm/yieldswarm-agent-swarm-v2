//! YieldSwarm Core — Phase 1 Swarm OS runtime.
//!
//! Prompts: 1 (orchestrator), 4 (registry), 5 (ElizaOS), 36 (elevators),
//!          37 (YSLR), 38 (14-Council), 43 (Apollo Nexus).

pub mod accelerator;
pub mod governance;
pub mod id;
pub mod orchestrator;
pub mod parser;
pub mod registry;

use serde::{Deserialize, Serialize};

/// Cross-agent message bus envelope.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SwarmMessage {
    pub id: String,
    pub source_agent: String,
    pub target_agent: Option<String>,
    /// Elevator lane 0..13 when using 14-elevator routing.
    pub elevator_lane: Option<u8>,
    pub payload: String,
    pub timestamp: u64,
}

impl SwarmMessage {
    pub fn broadcast(source_agent: impl Into<String>, payload: impl Into<String>) -> Self {
        Self {
            id: crate::id::new_id("msg"),
            source_agent: source_agent.into(),
            target_agent: None,
            elevator_lane: None,
            payload: payload.into(),
            timestamp: unix_now(),
        }
    }

    pub fn direct(
        source_agent: impl Into<String>,
        target_agent: impl Into<String>,
        payload: impl Into<String>,
    ) -> Self {
        Self {
            id: crate::id::new_id("msg"),
            source_agent: source_agent.into(),
            target_agent: Some(target_agent.into()),
            elevator_lane: None,
            payload: payload.into(),
            timestamp: unix_now(),
        }
    }
}

pub fn unix_now() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}
