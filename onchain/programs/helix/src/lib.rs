use anchor_lang::prelude::*;

pub mod events;
pub mod instructions;
pub mod mining_roots;
pub mod state;
pub mod zk_swarm;

use instructions::*;

declare_id!("Helx1111111111111111111111111111111111111");

#[program]
pub mod helix {
    use super::*;

    pub fn initialize_helix(ctx: Context<InitializeHelix>) -> Result<()> {
        instructions::initialize_helix::handler(ctx)
    }

    pub fn configure_mining_roots(
        ctx: Context<ConfigureMiningRoots>,
        iotex_treasury: [u8; 20],
        btc_bridge_hash: [u8; 32],
        root_hashes: [[u8; 32]; 10],
    ) -> Result<()> {
        instructions::configure_mining_roots::handler(
            ctx,
            iotex_treasury,
            btc_bridge_hash,
            root_hashes,
        )
    }

    pub fn route_to_mining_root(
        ctx: Context<RouteToMiningRoot>,
        amount: u64,
        destination: u8,
        source_chain_id: u32,
    ) -> Result<()> {
        instructions::route_mining_root::handler(ctx, amount, destination, source_chain_id)
    }

    pub fn submit_zk_swarm_batch(
        ctx: Context<SubmitZkSwarmBatch>,
        batch: zk_swarm::ZkSwarmProofBatch,
    ) -> Result<()> {
        instructions::route_mining_root::submit_zk_handler(ctx, batch)
    }
}
