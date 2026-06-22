use anchor_lang::prelude::*;

#[account]
pub struct HelixState {
    pub authority: Pubkey,
    pub nexus_treasury: Pubkey,
    pub total_routed: u64,
    pub zk_batches_verified: u64,
    pub bump: u8,
}

impl HelixState {
    pub const LEN: usize = 32 + 32 + 8 + 8 + 1;
}

#[account]
pub struct MiningRootConfig {
    pub authority: Pubkey,
    pub iotex_treasury: [u8; 20],
    pub btc_bridge_hash: [u8; 32],
    pub root_hashes: [[u8; 32]; 10],
    pub bump: u8,
}

impl MiningRootConfig {
    pub const LEN: usize = 32 + 20 + 32 + (32 * 10) + 1;
}
