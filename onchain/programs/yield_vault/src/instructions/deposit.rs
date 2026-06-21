use anchor_lang::prelude::*;
use crate::errors::VaultError;
use crate::state::VaultState;

#[derive(Accounts)]
pub struct Deposit<'info> {
    pub user: Signer<'info>,
    #[account(mut, seeds = [b"vault_state", vault_state.authority.as_ref()], bump = vault_state.bump)]
    pub vault_state: Account<'info, VaultState>,
}

pub fn handler(ctx: Context<Deposit>, amount: u64) -> Result<()> {
    require!(amount > 0, VaultError::SlippageExceeded);
    let vault = &mut ctx.accounts.vault_state;
    vault.total_assets = vault
        .total_assets
        .checked_add(amount)
        .ok_or(VaultError::MathOverflow)?;
    vault.total_shares = vault
        .total_shares
        .checked_add(amount)
        .ok_or(VaultError::MathOverflow)?;
    Ok(())
}
