use anchor_lang::prelude::*;

use crate::errors::CrossChainError;
use crate::events::{EventLog, EVENT_KIND_PAUSE};
use crate::state::TreasuryRegistry;

#[derive(Accounts)]
pub struct SetTreasuryPause<'info> {
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"treasury_registry"],
        bump = treasury_registry.bump,
        constraint = treasury_registry.authority == authority.key()
            || treasury_registry.nexus_authority == authority.key()
            @ CrossChainError::UnauthorizedTreasuryAdmin
    )]
    pub treasury_registry: Account<'info, TreasuryRegistry>,
}

pub fn handler(
    ctx: Context<SetTreasuryPause>,
    pause_sweeps: bool,
    pause_inflows: bool,
) -> Result<()> {
    let registry = &mut ctx.accounts.treasury_registry;
    registry.paused_sweeps = pause_sweeps;
    registry.paused_inflows = pause_inflows;

    emit!(EventLog {
        kind: EVENT_KIND_PAUSE,
        origin_chain_id: 0,
        asset_amount: if pause_sweeps as u64 { 1 } else { 0 }
            | (if pause_inflows as u64 { 2 } else { 0 }),
        agent: ctx.accounts.authority.key(),
        target_vault: registry.nexus_treasury,
        bridge_message_hash: [0u8; 32],
        timestamp: Clock::get()?.unix_timestamp,
    });

    Ok(())
}

#[derive(Accounts)]
#[instruction(root_kind: u8)]
pub struct UpdateMiningRoot<'info> {
    pub authority: Signer<'info>,
    #[account(
        seeds = [b"treasury_registry"],
        bump = treasury_registry.bump,
        constraint = treasury_registry.authority == authority.key()
            || treasury_registry.nexus_authority == authority.key()
            @ CrossChainError::UnauthorizedTreasuryAdmin
    )]
    pub treasury_registry: Account<'info, TreasuryRegistry>,
    #[account(
        mut,
        seeds = [b"mining_root", &[root_kind][..]],
        bump = mining_root.bump,
        constraint = mining_root.root_kind == root_kind @ CrossChainError::InvalidMiningRoot
    )]
    pub mining_root: Account<'info, crate::state::MiningRoot>,
}

pub fn update_mining_root_handler(
    ctx: Context<UpdateMiningRoot>,
    root_kind: u8,
    new_address: [u8; 64],
    address_len: u8,
    solana_recipient: Pubkey,
    active: bool,
) -> Result<()> {
    let _ = root_kind;
    require!(address_len > 0 && (address_len as usize) <= 64, CrossChainError::InvalidMiningRoot);

    let root = &mut ctx.accounts.mining_root;
    root.address = new_address;
    root.address_len = address_len;
    root.solana_recipient = solana_recipient;
    root.active = active;
    Ok(())
}

#[derive(Accounts)]
pub struct UpdateNexusTreasury<'info> {
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"treasury_registry"],
        bump = treasury_registry.bump,
        constraint = treasury_registry.nexus_authority == authority.key()
            @ CrossChainError::UnauthorizedTreasuryAdmin
    )]
    pub treasury_registry: Account<'info, TreasuryRegistry>,
}

pub fn update_nexus_treasury_handler(
    ctx: Context<UpdateNexusTreasury>,
    new_nexus_treasury: Pubkey,
) -> Result<()> {
    ctx.accounts.treasury_registry.nexus_treasury = new_nexus_treasury;
    Ok(())
}
