use anchor_lang::prelude::*;
use crate::state::ShardVault;

#[derive(Accounts)]
#[instruction(shard_id: u64)]
pub struct InitializeShard<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(
        init,
        payer = payer,
        space = 8 + ShardVault::LEN,
        seeds = [b"shard_vault", shard_id.to_le_bytes().as_ref()],
        bump
    )]
    pub shard_vault: Account<'info, ShardVault>,
    pub system_program: Program<'info, System>,
}

pub fn handler(_ctx: Context<InitializeShard>, _shard_id: u64) -> Result<()> {
    Ok(())
}
