use anchor_lang::prelude::*;
use crate::state::HelixState;

#[derive(Accounts)]
pub struct InitializeHelix<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = 8 + HelixState::LEN,
        seeds = [b"helix_state"],
        bump
    )]
    pub helix_state: Account<'info, HelixState>,
    /// CHECK: Nexus treasury pubkey from manifest
    pub nexus_treasury: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeHelix>) -> Result<()> {
    let h = &mut ctx.accounts.helix_state;
    h.authority = ctx.accounts.authority.key();
    h.nexus_treasury = ctx.accounts.nexus_treasury.key();
    h.total_routed = 0;
    h.zk_batches_verified = 0;
    h.bump = ctx.bumps.helix_state;
    Ok(())
}
