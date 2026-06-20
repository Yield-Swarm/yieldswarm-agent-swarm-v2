use anchor_lang::prelude::*;
use crate::state::AgentPermissionRegistry;

#[derive(Accounts)]
pub struct RegisterAgent<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    pub agent: Signer<'info>,
    #[account(
        init,
        payer = payer,
        space = 8 + AgentPermissionRegistry::LEN,
        seeds = [b"agent_registry", agent.key().as_ref()],
        bump
    )]
    pub agent_registry: Account<'info, AgentPermissionRegistry>,
    pub system_program: Program<'info, System>,
}

pub fn handler(_ctx: Context<RegisterAgent>) -> Result<()> {
    Ok(())
}
