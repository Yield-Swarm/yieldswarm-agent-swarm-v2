use anchor_lang::prelude::*;

pub mod errors;
pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("SwarmOps111111111111111111111111111111111");

const MAX_AGENTS: usize = 521;

#[program]
pub mod swarm_ops {
    use super::*;

    pub fn initialize_registry(
        ctx: Context<InitializeRegistry>,
        consensus_threshold: u8,
    ) -> Result<()> {
        instructions::initialize_registry::handler(ctx, consensus_threshold)
    }

    pub fn register_agent(
        ctx: Context<RegisterAgent>,
        agent_id: u32,
        risk_score_bps: u16,
        daily_spend_limit: u64,
        execution_boundary: u64,
    ) -> Result<()> {
        instructions::register_agent::handler(
            ctx,
            agent_id,
            risk_score_bps,
            daily_spend_limit,
            execution_boundary,
        )
    }

    pub fn propose_strategy(
        ctx: Context<ProposeStrategy>,
        proposal_id: u64,
        target_program: Pubkey,
        strategy_hash: [u8; 32],
        spend_amount: u64,
    ) -> Result<()> {
        instructions::propose_strategy::handler(
            ctx,
            proposal_id,
            target_program,
            strategy_hash,
            spend_amount,
        )
    }

    pub fn approve_strategy(ctx: Context<ApproveStrategy>, proposal_id: u64) -> Result<()> {
        instructions::approve_strategy::handler(ctx, proposal_id)
    }
}
