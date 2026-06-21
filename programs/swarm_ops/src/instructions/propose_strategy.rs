use anchor_lang::prelude::*;
use crate::errors::SwarmOpsError;
use crate::state::{AgentPermissionRegistry, StrategyProposal, SwarmRegistry};

fn current_day(ts: i64) -> u64 {
    (ts / 86_400) as u64
}

#[derive(Accounts)]
#[instruction(proposal_id: u64)]
pub struct ProposeStrategy<'info> {
    pub proposer: Signer<'info>,
    #[account(seeds = [b"swarm_registry"], bump = registry.bump)]
    pub registry: Account<'info, SwarmRegistry>,
    #[account(
        mut,
        seeds = [b"agent_perm", agent_perm.agent_id.to_le_bytes().as_ref()],
        bump = agent_perm.bump,
        constraint = agent_perm.agent_authority == proposer.key()
    )]
    pub agent_perm: Account<'info, AgentPermissionRegistry>,
    #[account(
        init,
        payer = proposer,
        space = StrategyProposal::LEN,
        seeds = [b"proposal", proposal_id.to_le_bytes().as_ref()],
        bump
    )]
    pub proposal: Account<'info, StrategyProposal>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<ProposeStrategy>,
    proposal_id: u64,
    target_program: Pubkey,
    strategy_hash: [u8; 32],
    spend_amount: u64,
) -> Result<()> {
    let now = Clock::get()?.unix_timestamp;
    let day = current_day(now);
    let perm = &mut ctx.accounts.agent_perm;

    if perm.last_reset_day != day {
        perm.daily_spent = 0;
        perm.last_reset_day = day;
    }

    let projected = perm.daily_spent.saturating_add(spend_amount);
    require!(projected <= perm.daily_spend_limit, SwarmOpsError::DailyLimitExceeded);
    require!(spend_amount <= perm.execution_boundary, SwarmOpsError::BoundaryExceeded);

    perm.daily_spent = projected;

    let p = &mut ctx.accounts.proposal;
    p.registry = ctx.accounts.registry.key();
    p.proposal_id = proposal_id;
    p.proposer = ctx.accounts.proposer.key();
    p.target_program = target_program;
    p.strategy_hash = strategy_hash;
    p.spend_amount = spend_amount;
    p.approval_count = 1;
    p.executed = false;
    p.bump = ctx.bumps.proposal;
    Ok(())
}
