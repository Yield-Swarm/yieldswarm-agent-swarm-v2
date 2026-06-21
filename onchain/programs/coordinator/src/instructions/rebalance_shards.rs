use anchor_lang::prelude::*;
use crate::state::{ShardVault, VaultCoordinator};

#[derive(Accounts)]
pub struct RebalanceShards<'info> {
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"vault_coordinator"],
        bump = coordinator.bump,
        constraint = coordinator.authority == authority.key()
    )]
    pub coordinator: Account<'info, VaultCoordinator>,
    #[account(mut)]
    pub shard_vault: Account<'info, ShardVault>,
}

pub fn handler(ctx: Context<RebalanceShards>) -> Result<()> {
    let clock = Clock::get()?;
    let coord = &mut ctx.accounts.coordinator;
    let shard = &mut ctx.accounts.shard_vault;
    coord.total_assets = coord.total_assets.saturating_add(shard.total_assets);
    coord.last_rebalance_ts = clock.unix_timestamp;
    Ok(())
}
