use anchor_lang::prelude::*;

pub mod errors;
pub mod instructions;
pub mod multisig;
pub mod state;

use instructions::*;

declare_id!("Swrm1111111111111111111111111111111111111");

#[program]
pub mod swarm_ops {
    use super::*;

    pub fn register_agent(
        ctx: Context<RegisterAgent>,
        shard_id: u16,
        daily_spend_limit: u64,
    ) -> Result<()> {
        instructions::register_agent::handler(ctx, shard_id, daily_spend_limit)
    }

    pub fn propose_strategy(
        ctx: Context<ProposeStrategy>,
        proposal_id: u64,
        threshold: u8,
    ) -> Result<()> {
        instructions::propose_strategy::handler(ctx, proposal_id, threshold)
    }

    pub fn approve_strategy(ctx: Context<ApproveStrategy>) -> Result<()> {
        instructions::approve_strategy::handler(ctx)
    }
}
