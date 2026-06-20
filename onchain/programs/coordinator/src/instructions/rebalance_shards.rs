use anchor_lang::prelude::*;
use crate::state::ShardVault;

#[derive(Accounts)]
pub struct RebalanceShards<'info> {
    pub authority: Signer<'info>,
    #[account(mut)]
    pub shard_vault: Account<'info, ShardVault>,
}

pub fn handler(_ctx: Context<RebalanceShards>) -> Result<()> {
    Ok(())
}
