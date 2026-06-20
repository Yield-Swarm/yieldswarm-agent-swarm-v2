use anchor_lang::prelude::*;
use crate::state::ReferralRegistry;

#[derive(Accounts)]
pub struct ClaimRewards<'info> {
    pub claimant: Signer<'info>,
    #[account(seeds = [b"referral_registry"], bump = referral_registry.bump)]
    pub referral_registry: Account<'info, ReferralRegistry>,
}

pub fn handler(_ctx: Context<ClaimRewards>) -> Result<()> {
    Ok(())
}
