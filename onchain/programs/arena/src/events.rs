use anchor_lang::prelude::*;

#[event]
pub struct CompetitorRegistered {
    pub agent: Pubkey,
    pub shard_id: u16,
    pub authority: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct PerformanceSubmitted {
    pub agent: Pubkey,
    pub arena_score_bps: i32,
    pub signal_precision_bps: u16,
    pub pnl_bps: i32,
    pub reputation_bps: u16,
    pub timestamp: i64,
}

#[event]
pub struct RewardsDistributed {
    pub epoch: u64,
    pub agent: Pubkey,
    pub amount: u64,
    pub timestamp: i64,
}

#[event]
pub struct ReputationSlashed {
    pub agent: Pubkey,
    pub penalty_bps: u16,
    pub new_reputation_bps: u16,
    pub reason_hash: [u8; 32],
    pub timestamp: i64,
}

#[event]
pub struct ArenaZkBatchVerified {
    pub batch_id: u64,
    pub agent_count: u16,
    pub proof_hash: [u8; 32],
    pub verifier: Pubkey,
    pub timestamp: i64,
}
