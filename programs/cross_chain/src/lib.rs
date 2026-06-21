use anchor_lang::prelude::*;

pub mod errors;
pub mod events;
pub mod instructions;
pub mod state;

use instructions::*;

declare_id!("CrossChn1111111111111111111111111111111111");

#[program]
pub mod cross_chain {
    use super::*;

    pub fn initialize_treasury(
        ctx: Context<InitializeTreasury>,
        helix_chain_id: u64,
        bridge_authority: Pubkey,
    ) -> Result<()> {
        instructions::initialize_treasury::handler(ctx, helix_chain_id, bridge_authority)
    }

    pub fn trigger_remote_harvest(
        ctx: Context<TriggerRemoteHarvest>,
        origin_chain_id: u64,
        target_vault: Pubkey,
        harvest_amount: u64,
        agent_signature: [u8; 64],
    ) -> Result<()> {
        instructions::trigger_remote_harvest::handler(
            ctx,
            origin_chain_id,
            target_vault,
            harvest_amount,
            agent_signature,
        )
    }

    pub fn receive_cross_chain_yield(
        ctx: Context<ReceiveCrossChainYield>,
        origin_chain_id: u64,
        bridged_amount: u64,
        bridge_message_hash: [u8; 32],
        nonce: u64,
    ) -> Result<()> {
        instructions::receive_cross_chain_yield::handler(
            ctx,
            origin_chain_id,
            bridged_amount,
            bridge_message_hash,
            nonce,
        )
    }
}
