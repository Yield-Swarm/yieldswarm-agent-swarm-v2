use anchor_lang::prelude::*;

use cross_chain::state::{DEST_MINING_ROOT, DEST_NEXUS_TREASURY, SWEEP_EXTERNAL_MINING, SWEEP_INTERNAL_SOLANA};

use crate::errors::ShardCoordinatorError;
use crate::events::{ShardEventLog, EVENT_KIND_SHARD_CREATED};
use crate::state::{CoordinatorState, ShardVault, MAX_SHARDS};

#[derive(Accounts)]
#[instruction(shard_id: u16)]
pub struct CreateShardVault<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"coordinator"],
        bump = coordinator.bump,
        constraint = coordinator.authority == authority.key() @ ShardCoordinatorError::Unauthorized
    )]
    pub coordinator: Account<'info, CoordinatorState>,
    #[account(
        init,
        payer = authority,
        space = ShardVault::LEN,
        seeds = [b"shard_vault", shard_id.to_le_bytes().as_ref()],
        bump
    )]
    pub shard_vault: Account<'info, ShardVault>,
    pub system_program: Program<'info, System>,
}

pub fn handler(
    ctx: Context<CreateShardVault>,
    shard_id: u16,
    agent_authority: Pubkey,
    initial_efficiency_bps: u16,
    shard_type: u8,
    sweep_destination: u8,
    mining_root_kind: u8,
) -> Result<()> {
    require!(shard_id < MAX_SHARDS, ShardCoordinatorError::ShardIdOutOfRange);
    validate_sweep_config(shard_type, sweep_destination)?;

    let coordinator = &mut ctx.accounts.coordinator;
    coordinator.shard_count = coordinator
        .shard_count
        .checked_add(1)
        .ok_or(ShardCoordinatorError::Overflow)?;

    let vault = &mut ctx.accounts.shard_vault;
    vault.coordinator = coordinator.key();
    vault.shard_id = shard_id;
    vault.agent_authority = agent_authority;
    vault.liquidity = 0;
    vault.efficiency_bps = initial_efficiency_bps;
    vault.apy_bps = 0;
    vault.active = true;
    vault.shard_type = shard_type;
    vault.sweep_destination = sweep_destination;
    vault.mining_root_kind = mining_root_kind;
    vault.bump = ctx.bumps.shard_vault;

    emit!(ShardEventLog {
        kind: EVENT_KIND_SHARD_CREATED,
        shard_id,
        amount: 0,
        efficiency_bps: initial_efficiency_bps,
        agent: agent_authority,
        timestamp: Clock::get()?.unix_timestamp,
    });

    Ok(())
}

pub fn validate_sweep_config(shard_type: u8, sweep_destination: u8) -> Result<()> {
    match shard_type {
        SWEEP_INTERNAL_SOLANA => require!(
            sweep_destination == DEST_NEXUS_TREASURY,
            ShardCoordinatorError::InvalidSweepRoute
        ),
        SWEEP_EXTERNAL_MINING => require!(
            sweep_destination == DEST_MINING_ROOT,
            ShardCoordinatorError::InvalidSweepRoute
        ),
        _ => return Err(ShardCoordinatorError::InvalidSweepRoute.into()),
    }
    Ok(())
}
