use anchor_lang::prelude::*;

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
}
