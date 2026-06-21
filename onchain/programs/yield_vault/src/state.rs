use anchor_lang::prelude::*;

#[account]
pub struct VaultState {
    pub authority: Pubkey,
    pub total_assets: u64,
    pub total_shares: u64,
    /// Great Delta normalized weights (bps, sum = 10_000): core, growth, insurance, ops, reserve
    pub rebalance_bps: [u16; 5],
    pub last_harvest_ts: i64,
    pub bump: u8,
}

impl VaultState {
    pub const LEN: usize = 8 + 32 + 8 + 8 + (2 * 5) + 8 + 1;
}
