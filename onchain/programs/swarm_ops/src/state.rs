use anchor_lang::prelude::*;

pub const MAX_AGENTS: u16 = 521;
pub const SHARD_COUNT: u16 = 120;

#[account]
pub struct AgentPermissionRegistry {
    pub agent: Pubkey,
    pub authority: Pubkey,
    pub shard_id: u16,
    pub daily_spend_limit: u64,
    pub spent_today: u64,
    pub day_bucket: i64,
    pub risk_score_bps: u16,
    pub bump: u8,
}

impl AgentPermissionRegistry {
    pub const LEN: usize = 32 + 32 + 2 + 8 + 8 + 8 + 2 + 1;
}

#[account]
pub struct StrategyProposal {
    pub proposal_id: u64,
    pub proposer: Pubkey,
    pub approval_count: u8,
    pub threshold: u8,
    pub executed: bool,
    pub bump: u8,
}

impl StrategyProposal {
    pub const LEN: usize = 8 + 32 + 1 + 1 + 1 + 1;
}
