use anchor_lang::prelude::*;
use crate::chains::{
    YIELD_DEST_BTC_IOPAY, YIELD_DEST_IOTEX, YIELD_DEST_NEXUS, CHAIN_IOTEX,
};
use crate::errors::CrossChainError;
use crate::events::{
    CrossChainYieldReceived, EventLog, IotexYieldRouted, EVENT_KIND_IOTEX_INFLOW,
    EVENT_KIND_YIELD_RECEIVED,
};
use crate::state::{BridgeState, TreasuryRoutingConfig};

#[derive(Accounts)]
pub struct RouteCrossChainYield<'info> {
    pub relayer: Signer<'info>,
    #[account(
        mut,
        seeds = [b"bridge_state"],
        bump = bridge_state.bump,
        constraint = bridge_state.authority == relayer.key() @ CrossChainError::UnauthorizedRelayer
    )]
    pub bridge_state: Account<'info, BridgeState>,
    #[account(
        mut,
        seeds = [b"treasury_routing"],
        bump = routing_config.bump,
        constraint = routing_config.authority == relayer.key() @ CrossChainError::UnauthorizedRelayer
    )]
    pub routing_config: Account<'info, TreasuryRoutingConfig>,
    /// CHECK: nexus treasury when destination = Nexus; relayer forwards off-chain for IoTeX/BTC
    #[account(mut)]
    pub treasury: UncheckedAccount<'info>,
}

pub fn handler(
    ctx: Context<RouteCrossChainYield>,
    amount: u64,
    source_chain_id: u32,
    destination: u8,
) -> Result<()> {
    require!(amount > 0, CrossChainError::ZeroAmount);
    require!(destination <= YIELD_DEST_BTC_IOPAY, CrossChainError::InvalidDestination);

    let clock = Clock::get()?;
    let bridge = &mut ctx.accounts.bridge_state;
    let routing = &mut ctx.accounts.routing_config;

    bridge.total_received = bridge.total_received.saturating_add(amount);

    match destination {
        YIELD_DEST_NEXUS => {
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
        }
        YIELD_DEST_IOTEX => {
            routing.iotex_total_routed = routing.iotex_total_routed.saturating_add(amount);
            emit!(IotexYieldRouted {
                amount,
                source_chain_id,
                destination,
                iotex_treasury: routing.iotex_treasury,
                relayer: ctx.accounts.relayer.key(),
                timestamp: clock.unix_timestamp,
            });
            emit!(EventLog {
                kind: EVENT_KIND_IOTEX_INFLOW,
                program: crate::ID,
                actor: ctx.accounts.relayer.key(),
                amount,
                chain_id: CHAIN_IOTEX,
                signature_hash: routing.btc_bridge_hash,
                timestamp: clock.unix_timestamp,
            });
        }
        YIELD_DEST_BTC_IOPAY => {
            routing.btc_bridge_total_routed =
                routing.btc_bridge_total_routed.saturating_add(amount);
            emit!(IotexYieldRouted {
                amount,
                source_chain_id,
                destination,
                iotex_treasury: routing.iotex_treasury,
                relayer: ctx.accounts.relayer.key(),
                timestamp: clock.unix_timestamp,
            });
            emit!(EventLog {
                kind: EVENT_KIND_IOTEX_INFLOW,
                program: crate::ID,
                actor: ctx.accounts.relayer.key(),
                amount,
                chain_id: source_chain_id,
                signature_hash: routing.btc_bridge_hash,
                timestamp: clock.unix_timestamp,
            });
        }
        _ => return err!(CrossChainError::InvalidDestination),
    }

    Ok(())
}
