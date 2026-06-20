use anchor_lang::prelude::*;
use crate::errors::VaultError;
use crate::state::VaultState;

#[derive(Accounts)]
pub struct InitializeVault<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    #[account(
        init,
        payer = payer,
        space = 8 + VaultState::LEN,
        seeds = [b"vault_state", payer.key().as_ref()],
        bump
    )]
    pub vault_state: Account<'info, VaultState>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeVault>, rebalance_bps: [u16; 5]) -> Result<()> {
    let sum: u32 = rebalance_bps.iter().map(|v| *v as u32).sum();
    require!(sum == 10_000, VaultError::InvalidRebalanceSplit);
    let vault = &mut ctx.accounts.vault_state;
    vault.authority = ctx.accounts.payer.key();
    vault.rebalance_bps = rebalance_bps;
    vault.bump = ctx.bumps.vault_state;
    vault.last_harvest_ts = Clock::get()?.unix_timestamp;
    Ok(())
}
