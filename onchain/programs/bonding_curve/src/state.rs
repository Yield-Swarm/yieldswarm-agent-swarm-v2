use anchor_lang::prelude::*;

#[account]
pub struct BondingCurveState {
    pub mint: Pubkey,
    pub authority: Pubkey,
    pub bump: u8,
}

impl BondingCurveState {
    pub const LEN: usize = 32 + 32 + 1;
}

#[account]
pub struct ReferralRegistry {
    pub authority: Pubkey,
    pub bump: u8,
}

impl ReferralRegistry {
    pub const LEN: usize = 32 + 1;
}
