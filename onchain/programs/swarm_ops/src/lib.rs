use anchor_lang::prelude::*;

pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("Swrm1111111111111111111111111111111111111");

#[program]
pub mod swarm_ops {
    use super::*;

    pub fn register_agent(ctx: Context<RegisterAgent>) -> Result<()> {
        instructions::register_agent::handler(ctx)
    }

    pub fn propose_strategy(ctx: Context<ProposeStrategy>, proposal_id: u64) -> Result<()> {
        instructions::propose_strategy::handler(ctx, proposal_id)
    }

    pub fn approve_strategy(ctx: Context<ApproveStrategy>) -> Result<()> {
        instructions::approve_strategy::handler(ctx)
    }
}
