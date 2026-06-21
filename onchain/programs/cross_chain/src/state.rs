use anchor_lang::prelude::*;

#[account]
pub struct BridgeState {
    pub authority: Pubkey,
    pub treasury: Pubkey,
    pub total_received: u64,
    pub last_harvest_ts: i64,
    pub bump: u8,
}

impl BridgeState {
    pub const LEN: usize = 32 + 32 + 8 + 8 + 1;
}
