use anchor_lang::prelude::*;
use crate::errors::SwarmOpsError;
use crate::state::{ProposalApproval, StrategyProposal, SwarmRegistry};

#[derive(Accounts)]
#[instruction(proposal_id: u64)]
pub struct ApproveStrategy<'info> {
    pub approver: Signer<'info>,
    #[account(seeds = [b"swarm_registry"], bump = registry.bump)]
    pub registry: Account<'info, SwarmRegistry>,
    #[account(
        mut,
        seeds = [b"proposal", proposal_id.to_le_bytes().as_ref()],
        bump = proposal.bump,
        constraint = !proposal.executed @ SwarmOpsError::ProposalExecuted
    )]
    pub proposal: Account<'info, StrategyProposal>,
    #[account(
        init,
        payer = approver,
        space = ProposalApproval::LEN,
        seeds = [
            b"approval",
            proposal.key().as_ref(),
            approver.key().as_ref()
        ],
        bump
    )]
    pub approval_record: Account<'info, ProposalApproval>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<ApproveStrategy>, proposal_id: u64) -> Result<()> {
    let _ = proposal_id;
    let proposal = &mut ctx.accounts.proposal;

    let approval = &mut ctx.accounts.approval_record;
    approval.proposal = proposal.key();
    approval.approver_agent_id = 0;
    approval.approver = ctx.accounts.approver.key();
    approval.bump = ctx.bumps.approval_record;

    proposal.approval_count = proposal
        .approval_count
        .checked_add(1)
        .ok_or(ProgramError::ArithmeticOverflow)?;

    if proposal.approval_count >= ctx.accounts.registry.consensus_threshold {
        proposal.executed = true;
    }

    Ok(())
}
