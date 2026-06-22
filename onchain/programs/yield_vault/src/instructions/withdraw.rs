use anchor_lang::prelude::*;
use crate::errors::VaultError;
use crate::state::VaultState;

#[derive(Accounts)]
pub struct Withdraw<'info> {
    pub user: Signer<'info>,
    #[account(mut, seeds = [b"vault_state", vault_state.authority.as_ref()], bump = vault_state.bump)]
    pub vault_state: Account<'info, VaultState>,
}

pub fn handler(ctx: Context<Withdraw>, shares: u64) -> Result<()> {
    let vault = &mut ctx.accounts.vault_state;
    require!(shares <= vault.total_shares, VaultError::SlippageExceeded);
    vault.total_shares = vault.total_shares.checked_sub(shares).ok_or(VaultError::MathOverflow)?;
    vault.total_assets = vault.total_assets.checked_sub(shares).ok_or(VaultError::MathOverflow)?;
    Ok(())
}
