use anchor_lang::prelude::*;

pub mod errors;
pub mod events;
pub mod instructions;
pub mod mining_roots;
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

    pub fn initialize_treasury_registry(
        ctx: Context<InitializeTreasuryRegistry>,
        nexus_authority: Pubkey,
    ) -> Result<()> {
        instructions::initialize_treasury_registry::handler(ctx, nexus_authority)
    }

    pub fn initialize_mining_root(
        ctx: Context<InitializeMiningRoot>,
        root_kind: u8,
    ) -> Result<()> {
        instructions::initialize_treasury_registry::init_mining_root_handler(ctx, root_kind)
    }

    pub fn set_treasury_pause(
        ctx: Context<SetTreasuryPause>,
        pause_sweeps: bool,
        pause_inflows: bool,
    ) -> Result<()> {
        instructions::admin_treasury::handler(ctx, pause_sweeps, pause_inflows)
    }

    pub fn update_mining_root(
        ctx: Context<UpdateMiningRoot>,
        root_kind: u8,
        new_address: [u8; 64],
        address_len: u8,
        solana_recipient: Pubkey,
        active: bool,
    ) -> Result<()> {
        instructions::admin_treasury::update_mining_root_handler(
            ctx,
            root_kind,
            new_address,
            address_len,
            solana_recipient,
            active,
        )
    }

    pub fn update_nexus_treasury(
        ctx: Context<UpdateNexusTreasury>,
        new_nexus_treasury: Pubkey,
    ) -> Result<()> {
        instructions::admin_treasury::update_nexus_treasury_handler(ctx, new_nexus_treasury)
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
        route_destination: u8,
        mining_root_kind: u8,
    ) -> Result<()> {
        instructions::receive_cross_chain_yield::handler(
            ctx,
            origin_chain_id,
            bridged_amount,
            bridge_message_hash,
            nonce,
            route_destination,
            mining_root_kind,
        )
    }
}
