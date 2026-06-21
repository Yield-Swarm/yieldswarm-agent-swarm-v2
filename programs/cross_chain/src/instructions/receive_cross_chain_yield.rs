use anchor_lang::prelude::*;
use anchor_spl::token::{self, Token, TokenAccount, Transfer};

use crate::errors::CrossChainError;
use crate::events::{EventLog, TreasuryRouteEvent, EVENT_KIND_TREASURY_ROUTE, EVENT_KIND_YIELD_RECEIVED};
use crate::state::{
    CrossChainConfig, MiningRoot, TreasuryRegistry, TreasuryVault, CHAIN_SOLANA, DEST_MINING_ROOT,
    DEST_NEXUS_TREASURY,
};

#[derive(Accounts)]
pub struct ReceiveCrossChainYield<'info> {
    #[account(
        constraint = bridge_authority.key() == config.bridge_authority @ CrossChainError::UnauthorizedBridge
    )]
    pub bridge_authority: Signer<'info>,
    #[account(
        mut,
        seeds = [b"cross_chain_config"],
        bump = config.bump
    )]
    pub config: Account<'info, CrossChainConfig>,
    #[account(
        seeds = [b"treasury_registry"],
        bump = treasury_registry.bump
    )]
    pub treasury_registry: Account<'info, TreasuryRegistry>,
    #[account(
        mut,
        seeds = [b"treasury_vault", config.key().as_ref()],
        bump = treasury_vault.bump,
        constraint = treasury_vault.config == config.key() @ CrossChainError::TreasuryMismatch
    )]
    pub treasury_vault: Account<'info, TreasuryVault>,
    #[account(mut)]
    pub bridge_token_account: Account<'info, TokenAccount>,
    /// Destination SPL token account — Nexus Treasury ATA or Solana Mining Root ATA.
    #[account(mut)]
    pub destination_token: Account<'info, TokenAccount>,
    /// Mining root metadata when route_destination == DEST_MINING_ROOT.
    /// Optional for Nexus-only routes; validated when provided.
    pub mining_root: Option<Account<'info, MiningRoot>>,
    pub token_program: Program<'info, Token>,
}

pub fn handler(
    ctx: Context<ReceiveCrossChainYield>,
    origin_chain_id: u64,
    bridged_amount: u64,
    bridge_message_hash: [u8; 32],
    nonce: u64,
    route_destination: u8,
    mining_root_kind: u8,
) -> Result<()> {
    require!(bridged_amount > 0, CrossChainError::ZeroAmount);
    require!(!ctx.accounts.treasury_registry.paused_inflows, CrossChainError::InflowsPaused);
    require!(
        route_destination == DEST_NEXUS_TREASURY || route_destination == DEST_MINING_ROOT,
        CrossChainError::InvalidRouteDestination
    );

    let config = &mut ctx.accounts.config;
    require!(nonce > config.last_nonce, CrossChainError::NonceReplay);
    config.last_nonce = nonce;
    config.total_received = config
        .total_received
        .checked_add(bridged_amount)
        .ok_or(ProgramError::ArithmeticOverflow)?;

    let registry = &mut ctx.accounts.treasury_registry;
    let (recipient_owner, external_address, external_len, root_kind_out) =
        resolve_route(registry, route_destination, mining_root_kind, &ctx.accounts.mining_root)?;

    require!(
        ctx.accounts.destination_token.owner == recipient_owner,
        CrossChainError::RecipientOwnerMismatch
    );

    let cpi_accounts = Transfer {
        from: ctx.accounts.bridge_token_account.to_account_info(),
        to: ctx.accounts.destination_token.to_account_info(),
        authority: ctx.accounts.bridge_authority.to_account_info(),
    };
    token::transfer(
        CpiContext::new(ctx.accounts.token_program.to_account_info(), cpi_accounts),
        bridged_amount,
    )?;

    let vault = &mut ctx.accounts.treasury_vault;
    vault.balance = vault
        .balance
        .checked_add(bridged_amount)
        .ok_or(ProgramError::ArithmeticOverflow)?;

    if route_destination == DEST_NEXUS_TREASURY {
        registry.total_to_nexus = registry
            .total_to_nexus
            .checked_add(bridged_amount)
            .ok_or(ProgramError::ArithmeticOverflow)?;
    } else {
        registry.total_to_mining = registry
            .total_to_mining
            .checked_add(bridged_amount)
            .ok_or(ProgramError::ArithmeticOverflow)?;
        if let Some(root) = ctx.accounts.mining_root.as_mut() {
            root.total_routed = root
                .total_routed
                .checked_add(bridged_amount)
                .ok_or(ProgramError::ArithmeticOverflow)?;
        }
    }

    let ts = Clock::get()?.unix_timestamp;

    emit!(EventLog {
        kind: EVENT_KIND_YIELD_RECEIVED,
        origin_chain_id,
        asset_amount: bridged_amount,
        agent: ctx.accounts.bridge_authority.key(),
        target_vault: vault.key(),
        bridge_message_hash,
        timestamp: ts,
    });

    emit!(TreasuryRouteEvent {
        route_destination,
        mining_root_kind: root_kind_out,
        origin_chain_id,
        asset_amount: bridged_amount,
        solana_recipient: recipient_owner,
        external_address,
        external_address_len: external_len,
        bridge_message_hash,
        timestamp: ts,
    });

    Ok(())
}

fn resolve_route(
    registry: &TreasuryRegistry,
    route_destination: u8,
    mining_root_kind: u8,
    mining_root: &Option<Account<MiningRoot>>,
) -> Result<(Pubkey, [u8; 64], u8, u8)> {
    match route_destination {
        DEST_NEXUS_TREASURY => Ok((registry.nexus_treasury, [0u8; 64], 0, 0)),
        DEST_MINING_ROOT => {
            let root = mining_root.as_ref().ok_or(CrossChainError::InvalidMiningRoot)?;
            require!(root.active, CrossChainError::MiningRootInactive);
            require!(
                root.root_kind == mining_root_kind,
                CrossChainError::InvalidMiningRoot
            );

            let recipient = if root.chain_family == CHAIN_SOLANA {
                root.solana_recipient
            } else {
                // External roots: funds remain attributed on Solana ledger; bridge relayer
                // uses emitted TreasuryRouteEvent to complete outbound settlement.
                registry.nexus_treasury
            };

            Ok((
                recipient,
                root.address,
                root.address_len,
                root.root_kind,
            ))
        }
        _ => Err(CrossChainError::InvalidRouteDestination.into()),
    }
}
