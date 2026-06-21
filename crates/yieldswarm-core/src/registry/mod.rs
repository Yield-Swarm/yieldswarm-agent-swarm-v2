//! Sharded agent registry — Prompt 4 (10,000+ agents).

use dashmap::DashMap;
use serde::{Deserialize, Serialize};
use std::sync::Arc;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct AgentProfile {
    pub agent_id: String,
    pub capabilities: Vec<String>,
    pub status: String,
    /// Optional ElizaOS character id for Prompt 5 routing.
    pub eliza_character_id: Option<String>,
}

impl AgentProfile {
    pub fn new(agent_id: impl Into<String>, capabilities: Vec<String>) -> Self {
        Self {
            agent_id: agent_id.into(),
            capabilities,
            status: "active".to_string(),
            eliza_character_id: None,
        }
    }

    pub fn with_eliza(mut self, character_id: impl Into<String>) -> Self {
        self.eliza_character_id = Some(character_id.into());
        self
    }
}

/// Concurrent sharded map — 32 shards for lock-free scaling at 10k+ agents.
pub struct ShardedAgentRegistry {
    agents: Arc<DashMap<String, AgentProfile>>,
}

impl Default for ShardedAgentRegistry {
    fn default() -> Self {
        Self::new()
    }
}

impl ShardedAgentRegistry {
    pub fn new() -> Self {
        Self {
            agents: Arc::new(DashMap::with_shard_amount(32)),
        }
    }

    pub fn register_agent(&self, profile: AgentProfile) {
        self.agents.insert(profile.agent_id.clone(), profile);
    }

    pub fn get_agent(&self, agent_id: &str) -> Option<AgentProfile> {
        self.agents.get(agent_id).map(|r| r.value().clone())
    }

    pub fn list_by_capability(&self, capability: &str) -> Vec<AgentProfile> {
        self.agents
            .iter()
            .filter(|r| r.value().capabilities.iter().any(|c| c == capability))
            .map(|r| r.value().clone())
            .collect()
    }

    pub fn count(&self) -> usize {
        self.agents.len()
    }

    pub fn set_status(&self, agent_id: &str, status: impl Into<String>) -> bool {
        if let Some(mut entry) = self.agents.get_mut(agent_id) {
            entry.status = status.into();
            true
        } else {
            false
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn register_and_lookup() {
        let reg = ShardedAgentRegistry::new();
        reg.register_agent(AgentProfile::new(
            "agent-001",
            vec!["broadcast_listener".into()],
        ));
        assert_eq!(reg.count(), 1);
        assert!(reg.get_agent("agent-001").is_some());
    }
}
