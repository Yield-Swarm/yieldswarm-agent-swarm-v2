use anchor_lang::prelude::*;

#[account]
pub struct ShardVault {
    pub shard_id: u64,
    pub authority: Pubkey,
    pub total_assets: u64,
    pub bump: u8,
}

impl ShardVault {
    pub const LEN: usize = 8 + 32 + 8 + 1;
}
