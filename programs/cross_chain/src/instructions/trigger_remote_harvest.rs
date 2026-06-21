use anchor_lang::prelude::*;

use crate::errors::CrossChainError;
use crate::events::{EventLog, EVENT_KIND_HARVEST_TRIGGER};
use crate::state::CrossChainConfig;

#[derive(Accounts)]
pub struct TriggerRemoteHarvest<'info> {
    pub agent: Signer<'info>,
    #[account(
        mut,
        seeds = [b"cross_chain_config"],
        bump = config.bump
    )]
    pub config: Account<'info, CrossChainConfig>,
}

pub fn handler(
    ctx: Context<TriggerRemoteHarvest>,
    origin_chain_id: u64,
    target_vault: Pubkey,
    harvest_amount: u64,
    agent_signature: [u8; 64],
) -> Result<()> {
    require!(harvest_amount > 0, CrossChainError::ZeroAmount);

    let sig_valid = agent_signature.iter().any(|b| *b != 0);
    require!(sig_valid, CrossChainError::InvalidAgentSignature);

    let config = &mut ctx.accounts.config;
    config.total_harvested = config
        .total_harvested
        .checked_add(harvest_amount)
        .ok_or(ProgramError::ArithmeticOverflow)?;

    let message_hash = anchor_lang::solana_program::hash::hashv(&[
        &origin_chain_id.to_le_bytes(),
        target_vault.as_ref(),
        &harvest_amount.to_le_bytes(),
        ctx.accounts.agent.key().as_ref(),
        &agent_signature,
    ])
    .to_bytes();

    emit!(EventLog {
        kind: EVENT_KIND_HARVEST_TRIGGER,
        origin_chain_id,
        asset_amount: harvest_amount,
        agent: ctx.accounts.agent.key(),
        target_vault,
        bridge_message_hash: message_hash,
        timestamp: Clock::get()?.unix_timestamp,
    });

    Ok(())
}
