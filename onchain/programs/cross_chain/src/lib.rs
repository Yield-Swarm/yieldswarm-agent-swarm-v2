use anchor_lang::prelude::*;

pub mod events;
pub mod instructions;

use instructions::*;

declare_id!("XChn1111111111111111111111111111111111111");

#[program]
pub mod cross_chain {
    use super::*;

    pub fn trigger_remote_harvest(ctx: Context<TriggerRemoteHarvest>) -> Result<()> {
        instructions::trigger_remote_harvest::handler(ctx)
    }

    pub fn receive_cross_chain_yield(
        ctx: Context<ReceiveCrossChainYield>,
        amount: u64,
    ) -> Result<()> {
        instructions::receive_cross_chain_yield::handler(ctx, amount)
    }
}
