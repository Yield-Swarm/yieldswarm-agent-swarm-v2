use anchor_lang::prelude::*;
use crate::errors::ArenaError;
use crate::events::RewardsDistributed;
use crate::state::{ArenaState, CompetitorRecord, RewardEpoch};

#[derive(Accounts)]
#[instruction(epoch: u64)]
pub struct DistributeRewards<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"arena_state"],
        bump = arena_state.bump,
        constraint = arena_state.authority == authority.key() @ ArenaError::Unauthorized
    )]
    pub arena_state: Account<'info, ArenaState>,
    #[account(
        init_if_needed,
        payer = authority,
        space = 8 + RewardEpoch::LEN,
        seeds = [b"reward_epoch", &epoch.to_le_bytes()],
        bump
    )]
    pub reward_epoch: Account<'info, RewardEpoch>,
    #[account(
        mut,
        seeds = [b"competitor", competitor.agent.as_ref()],
        bump = competitor.bump
    )]
    pub competitor: Account<'info, CompetitorRecord>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<DistributeRewards>, epoch: u64, amount: u64) -> Result<()> {
    require!(amount > 0, ArenaError::ZeroReward);

    let epoch_acct = &mut ctx.accounts.reward_epoch;
    if epoch_acct.epoch == 0 {
        epoch_acct.epoch = epoch;
        epoch_acct.total_pool = amount;
        epoch_acct.distributed = 0;
        epoch_acct.competitor_count = 0;
        epoch_acct.finalized = false;
        epoch_acct.bump = ctx.bumps.reward_epoch;
    }
    require!(!epoch_acct.finalized, ArenaError::EpochFinalized);

    let comp = &mut ctx.accounts.competitor;
    let weight = comp.reputation_bps.max(1) as u64;
    let share = amount.saturating_mul(weight) / 10_000u64;
    comp.rewards_claimed = comp.rewards_claimed.saturating_add(share);
    epoch_acct.distributed = epoch_acct.distributed.saturating_add(share);
    epoch_acct.competitor_count = epoch_acct.competitor_count.saturating_add(1);

    let arena = &mut ctx.accounts.arena_state;
    arena.total_rewards_distributed = arena.total_rewards_distributed.saturating_add(share);
    arena.current_epoch = epoch;

    emit!(RewardsDistributed {
        epoch,
        agent: comp.agent,
        amount: share,
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}
