use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

use crate::errors::CrossChainError;
use crate::events::{EventLog, EVENT_KIND_YIELD_RECEIVED};
use crate::state::{CrossChainConfig, TreasuryVault};

#[derive(Accounts)]
pub struct ReceiveCrossChainYield<'info> {
    #[account(
        constraint = bridge_authority.key() == config.bridge_authority @ CrossChainError::UnauthorizedBridge
    )]
    pub bridge_authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"cross_chain_config"],
        bump = config.bump
    )]
    pub config: Account<'info, CrossChainConfig>,
    #[account(
        mut,
        seeds = [b"treasury_vault", config.key().as_ref()],
        bump = treasury_vault.bump,
        constraint = treasury_vault.config == config.key() @ CrossChainError::TreasuryMismatch
    )]
    pub treasury_vault: Account<'info, TreasuryVault>,
    #[account(mut)]
    pub bridge_token_account: Account<'info, TokenAccount>,
    #[account(
        mut,
        seeds = [b"treasury_token", config.key().as_ref()],
        bump
    )]
    pub treasury_token: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

pub fn handler(
    ctx: Context<ReceiveCrossChainYield>,
    origin_chain_id: u64,
    bridged_amount: u64,
    bridge_message_hash: [u8; 32],
    nonce: u64,
) -> Result<()> {
    require!(bridged_amount > 0, CrossChainError::ZeroAmount);

    let config = &mut ctx.accounts.config;
    require!(nonce > config.last_nonce, CrossChainError::NonceReplay);
    config.last_nonce = nonce;
    config.total_received = config
        .total_received
        .checked_add(bridged_amount)
        .ok_or(ProgramError::ArithmeticOverflow)?;

    let cpi_accounts = Transfer {
        from: ctx.accounts.bridge_token_account.to_account_info(),
        to: ctx.accounts.treasury_token.to_account_info(),
        authority: ctx.accounts.bridge_authority.to_account_info(),
    };
    token::transfer(
        CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts),
        bridged_amount,
    )?;

    let vault = &mut ctx.accounts.treasury_vault;
    vault.balance = vault
        .balance
        .checked_add(bridged_amount)
        .ok_or(ProgramError::ArithmeticOverflow)?;

    emit!(EventLog {
        kind: EVENT_KIND_YIELD_RECEIVED,
        origin_chain_id,
        asset_amount: bridged_amount,
        agent: ctx.accounts.bridge_authority.key(),
        target_vault: vault.key(),
        bridge_message_hash,
        timestamp: Clock::get()?.unix_timestamp,
    });

    Ok(())
}
