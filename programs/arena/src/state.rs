use anchor_lang::prelude::*;

/// Global Arena configuration (Shadow Chain / Kyle's chain).
#[account]
#[derive(InitSpace)]
pub struct ArenaState {
    pub authority: Pubkey,
    pub swarm_ops_program: Pubkey,
    pub reward_pool_lamports: u64,
    pub season: u32,
    pub paused: bool,
    pub competitor_count: u32,
    pub last_batch_root: [u8; 32],
    pub bump: u8,
}

impl ArenaState {
    pub const SEED: &'static [u8] = b"arena_state";
}

/// Per-agent competitor record linked to swarm_ops registry.
#[account]
#[derive(InitSpace)]
pub struct Competitor {
    pub arena: Pubkey,
    pub agent: Pubkey,
    pub reputation: u64,
    pub score: u64,
    pub wins: u32,
    pub losses: u32,
    pub rewards_claimed: u64,
    pub bump: u8,
}

impl Competitor {
    pub const SEED: &'static [u8] = b"competitor";
}

/// ZK-Swarm Mutation batch header for batched proofs.
#[account]
#[derive(InitSpace)]
pub struct ZkSwarmBatch {
    pub arena: Pubkey,
    pub batch_root: [u8; 32],
    pub proof_count: u8,
    pub verified: bool,
    pub submitted_at: i64,
    pub bump: u8,
}

impl ZkSwarmBatch {
    pub const SEED: &'static [u8] = b"zk_batch";
    pub const MAX_PROOFS: u8 = 64;
}
