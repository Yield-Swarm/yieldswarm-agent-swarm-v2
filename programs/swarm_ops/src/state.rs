use anchor_lang::prelude::*;

pub const MAX_APPROVERS: usize = 16;

#[account]
pub struct SwarmRegistry {
    pub authority: Pubkey,
    pub agent_count: u32,
    pub consensus_threshold: u8,
    pub bump: u8,
}

impl SwarmRegistry {
    pub const LEN: usize = 8 + 32 + 4 + 1 + 1;
}

/// Sharded per-agent PDA: seeds = [b"agent_perm", agent_id.to_le_bytes()]
#[account]
pub struct AgentPermissionRegistry {
    pub registry: Pubkey,
    pub agent_id: u32,
    pub agent_authority: Pubkey,
    pub risk_score_bps: u16,
    pub daily_spend_limit: u64,
    pub daily_spent: u64,
    pub execution_boundary: u64,
    pub last_reset_day: u64,
    pub bump: u8,
}

impl AgentPermissionRegistry {
    pub const LEN: usize = 8 + 32 + 4 + 32 + 2 + 8 + 8 + 8 + 8 + 1;
}

#[account]
pub struct StrategyProposal {
    pub registry: Pubkey,
    pub proposal_id: u64,
    pub proposer: Pubkey,
    pub target_program: Pubkey,
    pub strategy_hash: [u8; 32],
    pub spend_amount: u64,
    pub approval_count: u8,
    pub executed: bool,
    pub bump: u8,
}

impl StrategyProposal {
    pub const LEN: usize = 8 + 32 + 8 + 32 + 32 + 32 + 8 + 1 + 1 + 1;
}

#[account]
pub struct ProposalApproval {
    pub proposal: Pubkey,
    pub approver_agent_id: u32,
    pub approver: Pubkey,
    pub bump: u8,
}

impl ProposalApproval {
    pub const LEN: usize = 8 + 32 + 4 + 32 + 1;
}
