use anchor_lang::prelude::*;
use crate::errors::ArenaError;
use crate::events::ReputationSlashed;
use crate::state::{ArenaState, CompetitorRecord, REPUTATION_FLOOR_BPS};

#[derive(Accounts)]
pub struct SlashReputation<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        seeds = [b"arena_state"],
        bump = arena_state.bump,
        constraint = arena_state.authority == authority.key() @ ArenaError::Unauthorized
    )]
    pub arena_state: Account<'info, ArenaState>,
    #[account(
        mut,
        seeds = [b"competitor", competitor.agent.as_ref()],
        bump = competitor.bump
    )]
    pub competitor: Account<'info, CompetitorRecord>,
}

pub fn handler(
    ctx: Context<SlashReputation>,
    penalty_bps: u16,
    reason_hash: [u8; 32],
) -> Result<()> {
    require!(penalty_bps > 0 && penalty_bps <= 5_000, ArenaError::InvalidPenalty);

    let comp = &mut ctx.accounts.competitor;
    let new_rep = comp.reputation_bps.saturating_sub(penalty_bps);
    require!(new_rep >= REPUTATION_FLOOR_BPS, ArenaError::ReputationTooLow);

    comp.reputation_bps = new_rep;
    comp.slashed_count = comp.slashed_count.saturating_add(1);

    emit!(ReputationSlashed {
        agent: comp.agent,
        penalty_bps,
        new_reputation_bps: new_rep,
        reason_hash,
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}
