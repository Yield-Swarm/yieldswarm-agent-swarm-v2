use anchor_lang::prelude::*;

use crate::state::CoordinatorState;

#[derive(Accounts)]
pub struct InitializeCoordinator<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = CoordinatorState::LEN,
        seeds = [b"coordinator"],
        bump
    )]
    pub coordinator: Account<'info, CoordinatorState>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<InitializeCoordinator>,
    mint: Pubkey,
    min_reserve_per_shard: u64,
    rebalance_threshold_bps: u16,
) -> Result<()> {
    let coordinator = &mut ctx.accounts.coordinator;
    coordinator.authority = ctx.accounts.authority.key();
    coordinator.mint = mint;
    coordinator.shard_count = 0;
    coordinator.total_liquidity = 0;
    coordinator.min_reserve_per_shard = min_reserve_per_shard;
    coordinator.rebalance_threshold_bps = rebalance_threshold_bps;
    coordinator.bump = ctx.bumps.coordinator;
    Ok(())
}
