use anchor_lang::prelude::*;
use crate::state::{BondingCurveState, ReferralRegistry};

#[derive(Accounts)]
pub struct InitializeCurve<'info> {
    #[account(mut)]
    pub payer: Signer<'info>,
    pub mint: Signer<'info>,
    #[account(
        init,
        payer = payer,
        space = 8 + BondingCurveState::LEN,
        seeds = [b"bonding_curve", mint.key().as_ref()],
        bump
    )]
    pub bonding_curve_state: Account<'info, BondingCurveState>,
    #[account(
        init,
        payer = payer,
        space = 8 + ReferralRegistry::LEN,
        seeds = [b"referral_registry"],
        bump
    )]
    pub referral_registry: Account<'info, ReferralRegistry>,
    pub system_program: Program<'info, System>,
}

pub fn handler(_ctx: Context<InitializeCurve>) -> Result<()> {
    Ok(())
}
