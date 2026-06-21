use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

use cross_chain::state::{
    MiningRoot, TreasuryRegistry, CHAIN_SOLANA, DEST_MINING_ROOT, DEST_NEXUS_TREASURY,
};

use crate::errors::ShardCoordinatorError;
use crate::events::{ShardSweepEvent, EVENT_KIND_SWEEP};
use crate::state::{CoordinatorState, ShardVault};

#[derive(Accounts)]
pub struct SweepShardProfits<'info> {
    #[account(
        constraint = agent.key() == shard_vault.agent_authority @ ShardCoordinatorError::Unauthorized
    )]
    pub agent: Signer<'info>,
    #[account(
        seeds = [b"coordinator"],
        bump = coordinator.bump
    )]
    pub coordinator: Account<'info, CoordinatorState>,
    #[account(
        mut,
        seeds = [b"shard_vault", shard_vault.shard_id.to_le_bytes().as_ref()],
        bump = shard_vault.bump,
        constraint = shard_vault.active @ ShardCoordinatorError::ShardInactive
    )]
    pub shard_vault: Account<'info, ShardVault>,
    /// CHECK: cross_chain program id stored on coordinator
    #[account(
        constraint = cross_chain_program.key() == coordinator.cross_chain_program
            @ ShardCoordinatorError::TreasuryRegistryMismatch
    )]
    pub cross_chain_program: UncheckedAccount<'info>,
    #[account(
        mut,
        seeds = [b"treasury_registry"],
        bump = treasury_registry.bump,
        seeds::program = cross_chain_program.key()
    )]
    pub treasury_registry: Account<'info, TreasuryRegistry>,
    /// Optional mining root PDA — required when shard sweeps to DEST_MINING_ROOT.
    /// CHECK: owner and seeds validated in handler.
    pub mining_root: Option<UncheckedAccount<'info>>,
    #[account(mut)]
    pub shard_token: Account<'info, TokenAccount>,
    #[account(mut)]
    pub destination_token: Account<'info, TokenAccount>,
    /// CHECK: shard vault PDA signer for token authority
    #[account(
        seeds = [b"shard_vault", shard_vault.shard_id.to_le_bytes().as_ref()],
        bump = shard_vault.bump
    )]
    pub shard_vault_signer: UncheckedAccount<'info>,
    pub token_program: Program<'info, Token>,
}

pub fn handler(ctx: Context<SweepShardProfits>, sweep_amount: u64) -> Result<()> {
    require!(sweep_amount > 0, ShardCoordinatorError::ZeroAmount);
    require!(
        !ctx.accounts.treasury_registry.paused_sweeps,
        ShardCoordinatorError::SweepsPaused
    );

    let vault = &ctx.accounts.shard_vault;
    require!(
        vault.liquidity >= sweep_amount,
        ShardCoordinatorError::InsufficientLiquidity
    );

    let mining_root_data = if vault.sweep_destination == DEST_MINING_ROOT {
        Some(validate_mining_root(
            ctx.accounts.mining_root.as_ref(),
            ctx.accounts.cross_chain_program.key(),
            vault.mining_root_kind,
        )?)
    } else {
        None
    };

    let registry = &mut ctx.accounts.treasury_registry;
    let recipient = resolve_sweep_recipient(
        registry,
        vault.sweep_destination,
        vault.mining_root_kind,
        mining_root_data.as_ref(),
    )?;

    require!(
        ctx.accounts.destination_token.owner == recipient,
        ShardCoordinatorError::InvalidSweepRoute
    );

    let signer_seeds: &[&[u8]] = &[
        b"shard_vault",
        &vault.shard_id.to_le_bytes(),
        &[vault.bump],
    ];

    token::transfer(
        CpiContext::new_with_signer(
            ctx.accounts.token_program.to_account_info(),
            Transfer {
                from: ctx.accounts.shard_token.to_account_info(),
                to: ctx.accounts.destination_token.to_account_info(),
                authority: ctx.accounts.shard_vault_signer.to_account_info(),
            },
            &[signer_seeds],
        ),
        sweep_amount,
    )?;

    let vault_mut = &mut ctx.accounts.shard_vault;
    vault_mut.liquidity = vault_mut
        .liquidity
        .checked_sub(sweep_amount)
        .ok_or(ShardCoordinatorError::Overflow)?;

    let coordinator = &mut ctx.accounts.coordinator;
    coordinator.total_liquidity = coordinator
        .total_liquidity
        .checked_sub(sweep_amount)
        .ok_or(ShardCoordinatorError::Overflow)?;

    if vault.sweep_destination == DEST_NEXUS_TREASURY {
        registry.total_to_nexus = registry
            .total_to_nexus
            .checked_add(sweep_amount)
            .ok_or(ShardCoordinatorError::Overflow)?;
    } else {
        registry.total_to_mining = registry
            .total_to_mining
            .checked_add(sweep_amount)
            .ok_or(ShardCoordinatorError::Overflow)?;
    }

    emit!(ShardSweepEvent {
        shard_id: vault_mut.shard_id,
        sweep_amount,
        sweep_destination: vault_mut.sweep_destination,
        mining_root_kind: vault_mut.mining_root_kind,
        shard_type: vault_mut.shard_type,
        solana_recipient: recipient,
        agent: ctx.accounts.agent.key(),
        timestamp: Clock::get()?.unix_timestamp,
    });

    emit!(cross_chain::events::EventLog {
        kind: EVENT_KIND_SWEEP,
        origin_chain_id: 0,
        asset_amount: sweep_amount,
        agent: ctx.accounts.agent.key(),
        target_vault: registry.nexus_treasury,
        bridge_message_hash: [0u8; 32],
        timestamp: Clock::get()?.unix_timestamp,
    });

    Ok(())
}

fn resolve_sweep_recipient(
    registry: &TreasuryRegistry,
    sweep_destination: u8,
    mining_root_kind: u8,
    mining_root: Option<&MiningRoot>,
) -> Result<Pubkey> {
    match sweep_destination {
        DEST_NEXUS_TREASURY => Ok(registry.nexus_treasury),
        DEST_MINING_ROOT => {
            let root = mining_root.ok_or(ShardCoordinatorError::MiningRootMismatch)?;
            require!(root.root_kind == mining_root_kind, ShardCoordinatorError::MiningRootMismatch);
            require!(root.active, ShardCoordinatorError::MiningRootMismatch);

            if root.chain_family == CHAIN_SOLANA {
                Ok(root.solana_recipient)
            } else {
                Ok(registry.nexus_treasury)
            }
        }
        _ => Err(ShardCoordinatorError::InvalidSweepRoute.into()),
    }
}

fn validate_mining_root(
    account: Option<&UncheckedAccount<'_>>,
    cross_chain_program: Pubkey,
    mining_root_kind: u8,
) -> Result<MiningRoot> {
    let unchecked = account.ok_or(ShardCoordinatorError::MiningRootMismatch)?;
    require!(
        unchecked.owner == &cross_chain_program,
        ShardCoordinatorError::TreasuryRegistryMismatch
    );

    let (expected, bump) = Pubkey::find_program_address(
        &[b"mining_root", &[mining_root_kind]],
        &cross_chain_program,
    );
    require!(unchecked.key() == expected, ShardCoordinatorError::MiningRootMismatch);
    let _ = bump;

    let root: MiningRoot = AccountDeserialize::try_deserialize(&mut &unchecked.data.borrow()[..])?;
    require!(root.active, ShardCoordinatorError::MiningRootMismatch);
    require!(root.root_kind == mining_root_kind, ShardCoordinatorError::MiningRootMismatch);
    Ok(root)
}
