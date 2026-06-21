use anchor_lang::prelude::*;

pub const MAX_SHARDS: u16 = 64;

#[account]
pub struct CoordinatorState {
    pub authority: Pubkey,
    pub mint: Pubkey,
    pub shard_count: u16,
    pub total_liquidity: u64,
    pub min_reserve_per_shard: u64,
    pub rebalance_threshold_bps: u16,
    pub bump: u8,
}

impl CoordinatorState {
    pub const LEN: usize = 8 + 32 + 32 + 2 + 8 + 8 + 2 + 1;
}

/// PDA: seeds = [b"shard_vault", shard_id.to_le_bytes()]
#[account]
pub struct ShardVault {
    pub coordinator: Pubkey,
    pub shard_id: u16,
    pub agent_authority: Pubkey,
    pub liquidity: u64,
    pub efficiency_bps: u16,
    pub apy_bps: u16,
    pub active: bool,
    pub bump: u8,
}

impl ShardVault {
    pub const LEN: usize = 8 + 32 + 2 + 32 + 8 + 2 + 2 + 1 + 1;
}
