use anchor_lang::prelude::*;
use crate::errors::CrossChainError;
use crate::events::{CrossChainYieldReceived, EventLog, EVENT_KIND_YIELD_RECEIVED};
use crate::state::BridgeState;

#[derive(Accounts)]
pub struct ReceiveCrossChainYield<'info> {
    pub relayer: Signer<'info>,
    #[account(
        mut,
        seeds = [b"bridge_state"],
        bump = bridge_state.bump,
        constraint = bridge_state.authority == relayer.key() @ CrossChainError::UnauthorizedRelayer
    )]
    pub bridge_state: Account<'info, BridgeState>,
    /// CHECK: treasury PDA receives bridged yield (Instance A wires CPI transfer)
    #[account(mut, address = bridge_state.treasury)]
    pub treasury: UncheckedAccount<'info>,
}

pub fn handler(ctx: Context<ReceiveCrossChainYield>, amount: u64, source_chain_id: u32) -> Result<()> {
    let clock = Clock::get()?;
    let bridge = &mut ctx.accounts.bridge_state;
    bridge.total_received = bridge.total_received.saturating_add(amount);
    emit!(CrossChainYieldReceived {
        amount,
        source_chain_id,
        treasury: bridge.treasury,
        agent: ctx.accounts.relayer.key(),
        timestamp: clock.unix_timestamp,
    });
    emit!(EventLog {
        kind: EVENT_KIND_YIELD_RECEIVED,
        program: crate::ID,
        actor: ctx.accounts.relayer.key(),
        amount,
        chain_id: source_chain_id,
        signature_hash: [0u8; 32],
        timestamp: clock.unix_timestamp,
    });
    Ok(())
}
