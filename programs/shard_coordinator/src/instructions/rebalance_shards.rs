use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

use crate::errors::ShardCoordinatorError;
use crate::events::{ShardEventLog, EVENT_KIND_REBALANCE_IN, EVENT_KIND_REBALANCE_OUT};
use crate::state::{CoordinatorState, ShardVault};
use crate::instructions::create_shard_vault::validate_sweep_config;

#[derive(Accounts)]
pub struct RebalanceShards<'info> {
    #[account(
        constraint = authority.key() == coordinator.authority @ ShardCoordinatorError::Unauthorized
    )]
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"coordinator"],
        bump = coordinator.bump
    )]
    pub coordinator: Account<'info, CoordinatorState>,
    #[account(
        mut,
        seeds = [b"shard_vault", source_shard.shard_id.to_le_bytes().as_ref()],
        bump = source_shard.bump,
        constraint = source_shard.active @ ShardCoordinatorError::ShardInactive
    )]
    pub source_shard: Account<'info, ShardVault>,
    #[account(
        mut,
        seeds = [b"shard_vault", dest_shard.shard_id.to_le_bytes().as_ref()],
        bump = dest_shard.bump,
        constraint = dest_shard.active @ ShardCoordinatorError::ShardInactive
    )]
    pub dest_shard: Account<'info, ShardVault>,
    #[account(mut)]
    pub source_token: Account<'info, TokenAccount>,
    #[account(mut)]
    pub dest_token: Account<'info, TokenAccount>,
    /// CHECK: PDA signer for shard token authority when using vault PDA as authority
    #[account(
        seeds = [b"shard_vault", source_shard.shard_id.to_le_bytes().as_ref()],
        bump = source_shard.bump
    )]
    pub source_vault_signer: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<RebalanceShards>, transfer_amount: u64) -> Result<()> {
    require!(transfer_amount > 0, ShardCoordinatorError::ZeroAmount);

    let source = &ctx.accounts.source_shard;
    let dest = &ctx.accounts.dest_shard;
    let coordinator = &ctx.accounts.coordinator;

    require!(
        source.shard_id != dest.shard_id,
        ShardCoordinatorError::Unauthorized
    );

    // Rebalance only between shards with compatible sweep routing (same type + destination).
    require!(
        source.shard_type == dest.shard_type
            && source.sweep_destination == dest.sweep_destination
            && source.mining_root_kind == dest.mining_root_kind,
        ShardCoordinatorError::InvalidSweepRoute
    );
    validate_sweep_config(source.shard_type, source.sweep_destination)?;

    let efficiency_gap = dest
        .efficiency_bps
        .saturating_sub(source.efficiency_bps);
    require!(
        efficiency_gap >= coordinator.rebalance_threshold_bps,
        ShardCoordinatorError::BelowMinReserve
    );

    let min_after = coordinator.min_reserve_per_shard;
    require!(
        source.liquidity.saturating_sub(transfer_amount) >= min_after,
        ShardCoordinatorError::InsufficientLiquidity
    );

    let signer_seeds: &[&[u8]] = &[
        b"shard_vault",
        &source.shard_id.to_le_bytes(),
        &[source.bump],
    ];

    let cpi_accounts = Transfer {
        from: ctx.accounts.source_token.to_account_info(),
        to: ctx.accounts.dest_token.to_account_info(),
        authority: ctx.accounts.source_vault_signer.to_account_info(),
    };
    token::transfer(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            cpi_accounts,
            &[signer_seeds],
        ),
        transfer_amount,
    )?;

    let source_mut = &mut ctx.accounts.source_shard;
    source_mut.liquidity = source_mut
        .liquidity
        .checked_sub(transfer_amount)
        .ok_or(ShardCoordinatorError::Overflow)?;

    let dest_mut = &mut ctx.accounts.dest_shard;
    dest_mut.liquidity = dest_mut
        .liquidity
        .checked_add(transfer_amount)
        .ok_or(ShardCoordinatorError::Overflow)?;

    let ts = Clock::get()?.unix_timestamp;

    emit!(ShardEventLog {
        kind: EVENT_KIND_REBALANCE_OUT,
        shard_id: source_mut.shard_id,
        amount: transfer_amount,
        efficiency_bps: source_mut.efficiency_bps,
        agent: ctx.accounts.authority.key(),
        timestamp: ts,
    });

    emit!(ShardEventLog {
        kind: EVENT_KIND_REBALANCE_IN,
        shard_id: dest_mut.shard_id,
        amount: transfer_amount,
        efficiency_bps: dest_mut.efficiency_bps,
        agent: ctx.accounts.authority.key(),
        timestamp: ts,
    });

    Ok(())
}
