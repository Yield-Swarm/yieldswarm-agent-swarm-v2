use anchor_lang::prelude::*;
use crate::state::VaultState;

#[derive(Accounts)]
pub struct RebalanceAndHarvest<'info> {
    pub operator: Signer<'info>,
    #[account(mut, seeds = [b"vault_state", vault_state.authority.as_ref()], bump = vault_state.bump)]
    pub vault_state: Account<'info, VaultState>,
}

pub fn handler(ctx: Context<RebalanceAndHarvest>) -> Result<()> {
    let vault = &mut ctx.accounts.vault_state;
    vault.last_harvest_ts = Clock::get()?.unix_timestamp;
    // CPI hooks to JitoSOL / Kamino — Instance A GP1 extends here
    Ok(())
}
