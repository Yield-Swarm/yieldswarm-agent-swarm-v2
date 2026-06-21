use anchor_lang::prelude::*;
use crate::state::BridgeState;

#[derive(Accounts)]
pub struct InitializeBridge<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = 8 + BridgeState::LEN,
        seeds = [b"bridge_state"],
        bump
    )]
    pub bridge_state: Account<'info, BridgeState>,
    /// CHECK: treasury PDA owned by yield_vault (Instance A CPI)
    pub treasury: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeBridge>) -> Result<()> {
    let bridge = &mut ctx.accounts.bridge_state;
    bridge.authority = ctx.accounts.authority.key();
    bridge.treasury = ctx.accounts.treasury.key();
    bridge.total_received = 0;
    bridge.last_harvest_ts = 0;
    bridge.bump = ctx.bumps.bridge_state;
    Ok(())
}
