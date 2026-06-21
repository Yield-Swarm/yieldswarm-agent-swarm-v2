use anchor_lang::prelude::*;

#[account]
pub struct ShardVault {
    pub shard_id: u64,
    pub authority: Pubkey,
    pub total_assets: u64,
    pub target_weight_bps: u16,
    pub bump: u8,
}

impl ShardVault {
    pub const LEN: usize = 8 + 32 + 8 + 2 + 1;
}

#[account]
pub struct VaultCoordinator {
    pub authority: Pubkey,
    pub shard_count: u16,
    pub total_assets: u64,
    pub last_rebalance_ts: i64,
    pub bump: u8,
}

impl VaultCoordinator {
    pub const LEN: usize = 32 + 2 + 8 + 8 + 1;
}

pub const MAX_SHARDS: u16 = 120;
