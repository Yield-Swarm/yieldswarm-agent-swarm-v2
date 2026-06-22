use anchor_lang::prelude::*;

pub const MAX_COMPETITORS: u16 = 521;
pub const REPUTATION_FLOOR_BPS: u16 = 100;
pub const REPUTATION_CEILING_BPS: u16 = 10_000;

#[account]
pub struct ArenaState {
    pub authority: Pubkey,
    pub reward_vault: Pubkey,
    pub swarm_ops_program: Pubkey,
    pub max_competitors: u16,
    pub competitor_count: u16,
    pub total_rewards_distributed: u64,
    pub zk_batches_verified: u64,
    pub current_epoch: u64,
    pub bump: u8,
}

impl ArenaState {
    pub const LEN: usize = 32 + 32 + 32 + 2 + 2 + 8 + 8 + 8 + 1;
}

#[account]
pub struct CompetitorRecord {
    pub agent: Pubkey,
    pub authority: Pubkey,
    pub shard_id: u16,
    pub reputation_bps: u16,
    pub arena_score_bps: i32,
    pub signal_precision_bps: u16,
    pub pnl_bps: i32,
    pub rewards_claimed: u64,
    pub slashed_count: u16,
    pub bump: u8,
}

impl CompetitorRecord {
    pub const LEN: usize = 32 + 32 + 2 + 2 + 4 + 2 + 4 + 8 + 2 + 1;
}

#[account]
pub struct RewardEpoch {
    pub epoch: u64,
    pub total_pool: u64,
    pub distributed: u64,
    pub competitor_count: u16,
    pub finalized: bool,
    pub bump: u8,
}

impl RewardEpoch {
    pub const LEN: usize = 8 + 8 + 8 + 2 + 1 + 1;
}
