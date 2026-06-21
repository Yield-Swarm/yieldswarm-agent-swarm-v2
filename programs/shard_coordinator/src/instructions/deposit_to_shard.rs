use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

use crate::errors::ShardCoordinatorError;
use crate::events::{ShardEventLog, EVENT_KIND_DEPOSIT};
use crate::state::{CoordinatorState, ShardVault};

#[derive(Accounts)]
pub struct DepositToShard<'info> {
    pub depositor: Signer<'info>,
    #[account(
        mut,
        seeds = [b"coordinator"],
        bump = coordinator.bump
    )]
    pub coordinator: Account<'info, CoordinatorState>,
    #[account(
        mut,
        seeds = [b"shard_vault", shard_vault.shard_id.to_le_bytes().as_ref()],
        bump = shard_vault.bump,
        constraint = shard_vault.active @ ShardCoordinatorError::ShardInactive,
        constraint = shard_vault.coordinator == coordinator.key()
    )]
    pub shard_vault: Account<'info, ShardVault>,
    #[account(mut)]
    pub depositor_token: Account<'info, TokenAccount>,
    #[account(mut)]
    pub shard_token: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<DepositToShard>, amount: u64) -> Result<()> {
    require!(amount > 0, ShardCoordinatorError::ZeroAmount);

    let cpi_accounts = Transfer {
        from: ctx.accounts.depositor_token.to_account_info(),
        to: ctx.accounts.shard_token.to_account_info(),
        authority: ctx.accounts.depositor.to_account_info(),
    };
    token::transfer(
        CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts),
        amount,
    )?;

    let vault = &mut ctx.accounts.shard_vault;
    vault.liquidity = vault
        .liquidity
        .checked_add(amount)
        .ok_or(ShardCoordinatorError::Overflow)?;

    let coordinator = &mut ctx.accounts.coordinator;
    coordinator.total_liquidity = coordinator
        .total_liquidity
        .checked_add(amount)
        .ok_or(ShardCoordinatorError::Overflow)?;

    emit!(ShardEventLog {
        kind: EVENT_KIND_DEPOSIT,
        shard_id: vault.shard_id,
        amount,
        efficiency_bps: vault.efficiency_bps,
        agent: ctx.accounts.depositor.key(),
        timestamp: Clock::get()?.unix_timestamp,
    });

    Ok(())
}
