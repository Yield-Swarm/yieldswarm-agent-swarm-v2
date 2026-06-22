use anchor_lang::prelude::*;
use crate::state::StrategyProposal;

#[derive(Accounts)]
#[instruction(proposal_id: u64)]
pub struct ProposeStrategy<'info> {
    #[account(mut)]
    pub proposer: Signer<'info>,
    #[account(
        init,
        payer = proposer,
        space = 8 + StrategyProposal::LEN,
        seeds = [b"proposal", proposal_id.to_le_bytes().as_ref()],
        bump
    )]
    pub proposal: Account<'info, StrategyProposal>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<ProposeStrategy>, proposal_id: u64, threshold: u8) -> Result<()> {
    let p = &mut ctx.accounts.proposal;
    p.proposal_id = proposal_id;
    p.proposer = ctx.accounts.proposer.key();
    p.approval_count = 1;
    p.threshold = threshold.max(1);
    p.executed = false;
    p.bump = ctx.bumps.proposal;
    Ok(())
}
