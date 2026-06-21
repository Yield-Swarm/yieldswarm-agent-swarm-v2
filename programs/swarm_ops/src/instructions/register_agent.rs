use anchor_lang::prelude::*;
use crate::errors::SwarmOpsError;
use crate::state::{AgentPermissionRegistry, SwarmRegistry};

#[derive(Accounts)]
#[instruction(agent_id: u32)]
pub struct RegisterAgent<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"swarm_registry"],
        bump = registry.bump,
        has_one = authority
    )]
    pub registry: Account<'info, SwarmRegistry>,
    /// CHECK: agent signer pubkey stored on registry entry
    pub agent_authority: UncheckedAccount<'info>,
    #[account(
        init,
        payer = authority,
        space = AgentPermissionRegistry::LEN,
        seeds = [b"agent_perm", agent_id.to_le_bytes().as_ref()],
        bump
    )]
    pub agent_perm: Account<'info, AgentPermissionRegistry>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<RegisterAgent>,
    agent_id: u32,
    risk_score_bps: u16,
    daily_spend_limit: u64,
    execution_boundary: u64,
) -> Result<()> {
    require!(agent_id > 0 && agent_id <= 521, SwarmOpsError::InvalidAgentId);

    let perm = &mut ctx.accounts.agent_perm;
    perm.registry = ctx.accounts.registry.key();
    perm.agent_id = agent_id;
    perm.agent_authority = ctx.accounts.agent_authority.key();
    perm.risk_score_bps = risk_score_bps;
    perm.daily_spend_limit = daily_spend_limit;
    perm.daily_spent = 0;
    perm.execution_boundary = execution_boundary;
    perm.last_reset_day = 0;
    perm.bump = ctx.bumps.agent_perm;

    ctx.accounts.registry.agent_count = ctx.accounts.registry.agent_count.saturating_add(1);
    Ok(())
}
