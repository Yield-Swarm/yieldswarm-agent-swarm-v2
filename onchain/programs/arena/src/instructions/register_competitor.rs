use anchor_lang::prelude::*;
use anchor_lang::solana_program::program::invoke;
use anchor_lang::solana_program::instruction::Instruction;
use crate::errors::ArenaError;
use crate::events::CompetitorRegistered;
use crate::state::{ArenaState, CompetitorRecord, MAX_COMPETITORS, REPUTATION_CEILING_BPS};

#[derive(Accounts)]
pub struct RegisterCompetitor<'info> {
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
        init,
        payer = authority,
        space = 8 + CompetitorRecord::LEN,
        seeds = [b"competitor", agent.key().as_ref()],
        bump
    )]
    pub competitor: Account<'info, CompetitorRecord>,
    /// CHECK: agent pubkey being registered
    pub agent: UncheckedAccount<'info>,
    /// CHECK: swarm_ops agent registry PDA (created via CPI)
    #[account(mut)]
    pub swarm_agent_registry: UncheckedAccount<'info>,
    /// CHECK: swarm_ops program
    pub swarm_ops_program: UncheckedAccount<'info>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<RegisterCompetitor>,
    shard_id: u16,
    daily_spend_limit: u64,
) -> Result<()> {
    let arena = &mut ctx.accounts.arena_state;
    require!(
        arena.competitor_count < arena.max_competitors.min(MAX_COMPETITORS),
        ArenaError::ArenaFull
    );

    // CPI into swarm_ops::register_agent so Shadow Chain competitors share the 521-agent mesh.
    let ix = Instruction {
        program_id: ctx.accounts.swarm_ops_program.key(),
        accounts: vec![
            anchor_lang::solana_program::instruction::AccountMeta::new(
                ctx.accounts.authority.key(),
                true,
            ),
            anchor_lang::solana_program::instruction::AccountMeta::new(
                ctx.accounts.swarm_agent_registry.key(),
                false,
            ),
            anchor_lang::solana_program::instruction::AccountMeta::new_readonly(
                ctx.accounts.agent.key(),
                false,
            ),
            anchor_lang::solana_program::instruction::AccountMeta::new_readonly(
                ctx.accounts.system_program.key(),
                false,
            ),
        ],
        data: build_register_agent_data(shard_id, daily_spend_limit),
    };
    invoke(
        &ix,
        &[
            ctx.accounts.authority.to_account_info(),
            ctx.accounts.swarm_agent_registry.to_account_info(),
            ctx.accounts.agent.to_account_info(),
            ctx.accounts.system_program.to_account_info(),
        ],
    )?;

    let comp = &mut ctx.accounts.competitor;
    comp.agent = ctx.accounts.agent.key();
    comp.authority = ctx.accounts.authority.key();
    comp.shard_id = shard_id;
    comp.reputation_bps = REPUTATION_CEILING_BPS / 2;
    comp.arena_score_bps = 0;
    comp.signal_precision_bps = 0;
    comp.pnl_bps = 0;
    comp.rewards_claimed = 0;
    comp.slashed_count = 0;
    comp.bump = ctx.bumps.competitor;

    arena.competitor_count = arena.competitor_count.saturating_add(1);

    emit!(CompetitorRegistered {
        agent: comp.agent,
        shard_id,
        authority: comp.authority,
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}

fn build_register_agent_data(shard_id: u16, daily_spend_limit: u64) -> Vec<u8> {
    // Anchor discriminator for swarm_ops::register_agent + args.
    let mut data = vec![0x8a, 0x1f, 0x3c, 0x9e, 0x2b, 0x7d, 0x4a, 0x6f];
    data.extend_from_slice(&shard_id.to_le_bytes());
    data.extend_from_slice(&daily_spend_limit.to_le_bytes());
    data
}
