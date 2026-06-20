use anchor_lang::prelude::*;

pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("Cord1111111111111111111111111111111111111");

#[program]
pub mod coordinator {
    use super::*;

    pub fn initialize_shard(ctx: Context<InitializeShard>, shard_id: u64) -> Result<()> {
        instructions::initialize_shard::handler(ctx, shard_id)
    }

    pub fn rebalance_shards(ctx: Context<RebalanceShards>) -> Result<()> {
        instructions::rebalance_shards::handler(ctx)
    }
}
