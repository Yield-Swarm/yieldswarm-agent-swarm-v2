use anchor_lang::prelude::*;
use crate::state::SwarmRegistry;

#[derive(Accounts)]
pub struct InitializeRegistry<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = SwarmRegistry::LEN,
        seeds = [b"swarm_registry"],
        bump
    )]
    pub registry: Account<'info, SwarmRegistry>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeRegistry>, consensus_threshold: u8) -> Result<()> {
    let reg = &mut ctx.accounts.registry;
    reg.authority = ctx.accounts.authority.key();
    reg.agent_count = 0;
    reg.consensus_threshold = consensus_threshold.max(1);
    reg.bump = ctx.bumps.registry;
    Ok(())
}
