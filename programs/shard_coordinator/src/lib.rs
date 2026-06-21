use anchor_lang::prelude::*;

pub mod errors;
pub mod events;
pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("ShardCrd111111111111111111111111111111111");

#[program]
pub mod shard_coordinator {
    use super::*;

    pub fn initialize_coordinator(
        ctx: Context<InitializeCoordinator>,
        mint: Pubkey,
        min_reserve_per_shard: u64,
        rebalance_threshold_bps: u16,
        cross_chain_program: Pubkey,
    ) -> Result<()> {
        instructions::initialize_coordinator::handler(
            ctx,
            mint,
            min_reserve_per_shard,
            rebalance_threshold_bps,
            cross_chain_program,
        )
    }

    pub fn create_shard_vault(
        ctx: Context<CreateShardVault>,
        shard_id: u16,
        agent_authority: Pubkey,
        initial_efficiency_bps: u16,
        shard_type: u8,
        sweep_destination: u8,
        mining_root_kind: u8,
    ) -> Result<()> {
        instructions::create_shard_vault::handler(
            ctx,
            shard_id,
            agent_authority,
            initial_efficiency_bps,
            shard_type,
            sweep_destination,
            mining_root_kind,
        )
    }

    pub fn deposit_to_shard(ctx: Context<DepositToShard>, amount: u64) -> Result<()> {
        instructions::deposit_to_shard::handler(ctx, amount)
    }

    pub fn rebalance_shards(ctx: Context<RebalanceShards>, transfer_amount: u64) -> Result<()> {
        instructions::rebalance_shards::handler(ctx, transfer_amount)
    }

    pub fn sweep_shard_profits(ctx: Context<SweepShardProfits>, sweep_amount: u64) -> Result<()> {
        instructions::sweep_shard_profits::handler(ctx, sweep_amount)
    }
}
