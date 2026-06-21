use anchor_lang::prelude::*;
use crate::state::VaultCoordinator;

#[derive(Accounts)]
pub struct InitializeCoordinator<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = 8 + VaultCoordinator::LEN,
        seeds = [b"vault_coordinator"],
        bump
    )]
    pub coordinator: Account<'info, VaultCoordinator>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeCoordinator>, shard_count: u16) -> Result<()> {
    let coord = &mut ctx.accounts.coordinator;
    coord.authority = ctx.accounts.authority.key();
    coord.shard_count = shard_count;
    coord.total_assets = 0;
    coord.last_rebalance_ts = 0;
    coord.bump = ctx.bumps.coordinator;
    Ok(())
}
