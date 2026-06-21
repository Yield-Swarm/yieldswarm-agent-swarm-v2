use anchor_lang::prelude::*;
use anchor_spl::token::{Mint, Token, TokenAccount};

use crate::state::{CrossChainConfig, TreasuryVault};

#[derive(Accounts)]
pub struct InitializeTreasury<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = CrossChainConfig::LEN,
        seeds = [b"cross_chain_config"],
        bump
    )]
    pub config: Account<'info, CrossChainConfig>,
    #[account(
        init,
        payer = authority,
        space = TreasuryVault::LEN,
        seeds = [b"treasury_vault", config.key().as_ref()],
        bump
    )]
    pub treasury_vault: Account<'info, TreasuryVault>,
    pub mint: Account<'info, Mint>,
    #[account(
        init,
        payer = authority,
        token::mint = mint,
        token::authority = treasury_vault,
        seeds = [b"treasury_token", config.key().as_ref()],
        bump
    )]
    pub treasury_token: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
    pub system_program: Program<'info, System>,
    pub rent: Sysvar<'info, Rent>,
}

pub fn handler(
    ctx: Context<InitializeTreasury>,
    helix_chain_id: u64,
    bridge_authority: Pubkey,
) -> Result<()> {
    let config = &mut ctx.accounts.config;
    config.authority = ctx.accounts.authority.key();
    config.bridge_authority = bridge_authority;
    config.treasury = ctx.accounts.treasury_vault.key();
    config.helix_chain_id = helix_chain_id;
    config.total_harvested = 0;
    config.total_received = 0;
    config.last_nonce = 0;
    config.bump = ctx.bumps.config;

    let vault = &mut ctx.accounts.treasury_vault;
    vault.config = config.key();
    vault.mint = ctx.accounts.mint.key();
    vault.balance = 0;
    vault.bump = ctx.bumps.treasury_vault;
    Ok(())
}
