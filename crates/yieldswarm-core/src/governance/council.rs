//! 14-member council quorum governance.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

pub const COUNCIL_SIZE: usize = 14;
pub const DEFAULT_QUORUM: usize = 9;

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct CouncilMember {
    pub id: String,
    pub name: String,
    pub domain: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum VoteOutcome {
    Approve,
    Reject,
    Abstain,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CouncilVote {
    pub member_id: String,
    pub outcome: VoteOutcome,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CouncilDecision {
    pub proposal_id: String,
    pub approved: bool,
    pub approve_count: usize,
    pub reject_count: usize,
    pub quorum_met: bool,
}

pub struct CouncilEngine {
    members: Vec<CouncilMember>,
    quorum: usize,
}

impl CouncilEngine {
    pub fn helix_default() -> Self {
        let domains = [
            "ingress", "tee", "horizons", "oracle", "agent_index", "depin",
            "tesla", "vault", "akash", "solenoid", "renaissance", "delta",
            "sovereign", "apex",
        ];
        let members = domains
            .iter()
            .enumerate()
            .map(|(i, d)| CouncilMember {
                id: format!("council-{:02}", i + 1),
                name: format!("Council {}", i + 1),
                domain: (*d).to_string(),
            })
            .collect();
        Self {
            members,
            quorum: DEFAULT_QUORUM,
        }
    }

    pub fn member_count(&self) -> usize {
        self.members.len()
    }

    pub fn members(&self) -> &[CouncilMember] {
        &self.members
    }

    /// Tally votes; approval requires quorum and strict majority of non-abstain.
    pub fn decide(&self, proposal_id: impl Into<String>, votes: &[CouncilVote]) -> CouncilDecision {
        let mut approve = 0usize;
        let mut reject = 0usize;
        let valid: HashMap<_, _> = self.members.iter().map(|m| (&m.id, m)).collect();

        for v in votes {
            if !valid.contains_key(&v.member_id) {
                continue;
            }
            match v.outcome {
                VoteOutcome::Approve => approve += 1,
                VoteOutcome::Reject => reject += 1,
                VoteOutcome::Abstain => {}
            }
        }

        let cast = approve + reject;
        let quorum_met = cast >= self.quorum;
        let approved = quorum_met && approve > reject;

        CouncilDecision {
            proposal_id: proposal_id.into(),
            approved,
            approve_count: approve,
            reject_count: reject,
            quorum_met,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn council_has_14_members() {
        assert_eq!(CouncilEngine::helix_default().member_count(), COUNCIL_SIZE);
    }

    #[test]
    fn approval_requires_quorum() {
        let engine = CouncilEngine::helix_default();
        let votes: Vec<CouncilVote> = (1..=9)
            .map(|i| CouncilVote {
                member_id: format!("council-{:02}", i),
                outcome: VoteOutcome::Approve,
            })
            .collect();
        let d = engine.decide("prop-1", &votes);
        assert!(d.quorum_met);
        assert!(d.approved);
    }
}
