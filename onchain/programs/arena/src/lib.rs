use anchor_lang::prelude::*;

pub mod errors;
pub mod events;
pub mod instructions;
pub mod state;
pub mod zk_swarm;

use instructions::*;

declare_id!("Arna1111111111111111111111111111111111111");

#[program]
pub mod arena {
    use super::*;

    pub fn initialize_arena(
        ctx: Context<InitializeArena>,
        max_competitors: u16,
    ) -> Result<()> {
        instructions::initialize_arena::handler(ctx, max_competitors)
    }

    pub fn register_competitor(
        ctx: Context<RegisterCompetitor>,
        shard_id: u16,
        daily_spend_limit: u64,
    ) -> Result<()> {
        instructions::register_competitor::handler(ctx, shard_id, daily_spend_limit)
    }

    pub fn submit_performance(
        ctx: Context<SubmitPerformance>,
        arena_score_bps: i32,
        signal_precision_bps: u16,
        pnl_bps: i32,
    ) -> Result<()> {
        instructions::submit_performance::handler(
            ctx,
            arena_score_bps,
            signal_precision_bps,
            pnl_bps,
        )
    }

    pub fn distribute_rewards(
        ctx: Context<DistributeRewards>,
        epoch: u64,
        amount: u64,
    ) -> Result<()> {
        instructions::distribute_rewards::handler(ctx, epoch, amount)
    }

    pub fn slash_reputation(
        ctx: Context<SlashReputation>,
        penalty_bps: u16,
        reason_hash: [u8; 32],
    ) -> Result<()> {
        instructions::slash_reputation::handler(ctx, penalty_bps, reason_hash)
    }

    pub fn submit_zk_swarm_batch(
        ctx: Context<SubmitArenaZkBatch>,
        batch: zk_swarm::ZkSwarmProofBatch,
    ) -> Result<()> {
        instructions::submit_zk_batch::handler(ctx, batch)
    }
}
