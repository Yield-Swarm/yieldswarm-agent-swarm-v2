use anchor_lang::prelude::*;
use crate::state::{ArenaState, MAX_COMPETITORS};

#[derive(Accounts)]
pub struct InitializeArena<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = 8 + ArenaState::LEN,
        seeds = [b"arena_state"],
        bump
    )]
    pub arena_state: Account<'info, ArenaState>,
    /// CHECK: reward vault authority (treasury PDA or multisig)
    pub reward_vault: UncheckedAccount<'info>,
    /// CHECK: swarm_ops program for CPI registration
    pub swarm_ops_program: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeArena>, max_competitors: u16) -> Result<()> {
    let cap = if max_competitors == 0 {
        MAX_COMPETITORS
    } else {
        max_competitors.min(MAX_COMPETITORS)
    };
    let arena = &mut ctx.accounts.arena_state;
    arena.authority = ctx.accounts.authority.key();
    arena.reward_vault = ctx.accounts.reward_vault.key();
    arena.swarm_ops_program = ctx.accounts.swarm_ops_program.key();
    arena.max_competitors = cap;
    arena.competitor_count = 0;
    arena.total_rewards_distributed = 0;
    arena.zk_batches_verified = 0;
    arena.current_epoch = 0;
    arena.bump = ctx.bumps.arena_state;
    Ok(())
}
