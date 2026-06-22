use anchor_lang::prelude::*;
use crate::errors::SwarmOpsError;
use crate::state::{AgentPermissionRegistry, SHARD_COUNT};

#[derive(Accounts)]
pub struct RegisterAgent<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = 8 + AgentPermissionRegistry::LEN,
        seeds = [b"agent_registry", agent.key().as_ref()],
        bump
    )]
    pub registry: Account<'info, AgentPermissionRegistry>,
    /// CHECK: agent being registered
    pub agent: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<RegisterAgent>,
    shard_id: u16,
    daily_spend_limit: u64,
) -> Result<()> {
    require!(shard_id < SHARD_COUNT, SwarmOpsError::ShardOverflow);
    let reg = &mut ctx.accounts.registry;
    reg.agent = ctx.accounts.agent.key();
    reg.authority = ctx.accounts.authority.key();
    reg.shard_id = shard_id;
    reg.daily_spend_limit = daily_spend_limit;
    reg.spent_today = 0;
    reg.day_bucket = Clock::get()?.unix_timestamp / 86_400;
    reg.risk_score_bps = 5000;
    reg.bump = ctx.bumps.registry;
    Ok(())
}
