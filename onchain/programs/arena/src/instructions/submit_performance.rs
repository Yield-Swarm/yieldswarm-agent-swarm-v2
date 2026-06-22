use anchor_lang::prelude::*;
use crate::errors::ArenaError;
use crate::events::PerformanceSubmitted;
use crate::state::{CompetitorRecord, REPUTATION_CEILING_BPS, REPUTATION_FLOOR_BPS};

#[derive(Accounts)]
pub struct SubmitPerformance<'info> {
    pub reporter: Signer<'info>,
    #[account(
        mut,
        seeds = [b"competitor", competitor.agent.as_ref()],
        bump = competitor.bump,
        constraint = competitor.authority == reporter.key() @ ArenaError::Unauthorized
    )]
    pub competitor: Account<'info, CompetitorRecord>,
}

pub fn handler(
    ctx: Context<SubmitPerformance>,
    arena_score_bps: i32,
    signal_precision_bps: u16,
    pnl_bps: i32,
) -> Result<()> {
    let comp = &mut ctx.accounts.competitor;
    comp.arena_score_bps = arena_score_bps;
    comp.signal_precision_bps = signal_precision_bps;
    comp.pnl_bps = pnl_bps;

    let delta: i32 = (arena_score_bps / 100)
        .saturating_add((pnl_bps / 200) as i32)
        .saturating_add((signal_precision_bps as i32) / 500);
    let new_rep = (comp.reputation_bps as i32).saturating_add(delta);
    comp.reputation_bps = new_rep
        .max(REPUTATION_FLOOR_BPS as i32)
        .min(REPUTATION_CEILING_BPS as i32) as u16;

    emit!(PerformanceSubmitted {
        agent: comp.agent,
        arena_score_bps,
        signal_precision_bps,
        pnl_bps,
        reputation_bps: comp.reputation_bps,
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}
