use anchor_lang::prelude::*;

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq)]
pub enum Role {
    Admin,
    Operator,
    Agent,
}

#[account]
pub struct AgentRegistry {
    pub agent: Pubkey,
    pub role: Role,
    pub bump: u8,
}

impl AgentRegistry {
    pub const LEN: usize = 32 + 1 + 1;
}
