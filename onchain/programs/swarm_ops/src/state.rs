use anchor_lang::prelude::*;

#[account]
pub struct AgentPermissionRegistry {
    pub agent: Pubkey,
    pub authority: Pubkey,
    pub bump: u8,
}

impl AgentPermissionRegistry {
    pub const LEN: usize = 32 + 32 + 1;
}
