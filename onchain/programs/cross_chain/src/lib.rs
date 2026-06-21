use anchor_lang::prelude::*;

pub mod chains;
pub mod errors;
pub mod events;
pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("XChn1111111111111111111111111111111111111");

#[program]
pub mod cross_chain {
    use super::*;

    pub fn initialize_bridge(ctx: Context<InitializeBridge>) -> Result<()> {
        instructions::initialize_bridge::handler(ctx)
    }

    pub fn trigger_remote_harvest(
        ctx: Context<TriggerRemoteHarvest>,
        origin_chain_id: u32,
    ) -> Result<()> {
        instructions::trigger_remote_harvest::handler(ctx, origin_chain_id)
    }

    pub fn receive_cross_chain_yield(
        ctx: Context<ReceiveCrossChainYield>,
        amount: u64,
        source_chain_id: u32,
    ) -> Result<()> {
        instructions::receive_cross_chain_yield::handler(ctx, amount, source_chain_id)
    }

    pub fn configure_treasury_routing(
        ctx: Context<ConfigureTreasuryRouting>,
        iotex_treasury: [u8; 20],
        btc_bridge_hash: [u8; 32],
        default_destination: u8,
    ) -> Result<()> {
        instructions::configure_treasury_routing::handler(
            ctx,
            iotex_treasury,
            btc_bridge_hash,
            default_destination,
        )
    }

    pub fn route_cross_chain_yield(
        ctx: Context<RouteCrossChainYield>,
        amount: u64,
        source_chain_id: u32,
        destination: u8,
    ) -> Result<()> {
        instructions::route_cross_chain_yield::handler(ctx, amount, source_chain_id, destination)
    }
}
