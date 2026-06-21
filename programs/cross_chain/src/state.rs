use anchor_lang::prelude::*;

#[account]
pub struct CrossChainConfig {
    pub authority: Pubkey,
    pub bridge_authority: Pubkey,
    pub treasury: Pubkey,
    pub helix_chain_id: u64,
    pub total_harvested: u64,
    pub total_received: u64,
    pub last_nonce: u64,
    pub bump: u8,
}

impl CrossChainConfig {
    pub const LEN: usize = 8 + 32 + 32 + 32 + 8 + 8 + 8 + 8 + 1;
}

#[account]
pub struct TreasuryVault {
    pub config: Pubkey,
    pub mint: Pubkey,
    pub balance: u64,
    pub bump: u8,
}

impl TreasuryVault {
    pub const LEN: usize = 8 + 32 + 32 + 8 + 1;
}
