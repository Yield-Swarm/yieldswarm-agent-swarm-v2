use anchor_lang::prelude::*;
use crate::errors::SwarmOpsError;
use crate::multisig;
use crate::state::StrategyProposal;

#[derive(Accounts)]
pub struct ApproveStrategy<'info> {
    pub approver: Signer<'info>,
    #[account(mut, seeds = [b"proposal", proposal.proposal_id.to_le_bytes().as_ref()], bump = proposal.bump)]
    pub proposal: Account<'info, StrategyProposal>,
}

pub fn handler(ctx: Context<ApproveStrategy>) -> Result<()> {
    let p = &mut ctx.accounts.proposal;
    require!(!p.executed, SwarmOpsError::AlreadyExecuted);
    p.approval_count = p.approval_count.saturating_add(1);
    if multisig::record_approval(p.approval_count.saturating_sub(1), p.threshold)? {
        p.executed = true;
    }
    Ok(())
}
