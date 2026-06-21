use anchor_lang::prelude::*;
use crate::state::BondingCurveState;

#[derive(Accounts)]
pub struct Sell<'info> {
    pub seller: Signer<'info>,
    #[account(seeds = [b"bonding_curve", bonding_curve_state.mint.as_ref()], bump = bonding_curve_state.bump)]
    pub bonding_curve_state: Account<'info, BondingCurveState>,
}

pub fn handler(_ctx: Context<Sell>, _amount: u64) -> Result<()> {
    Ok(())
}
