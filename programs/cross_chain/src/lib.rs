use anchor_lang::prelude::*;
use anchor_lang::system_program::{self, Transfer};

pub mod errors;
pub mod events;
pub mod state;
pub mod verify;

use errors::CrossChainError;
use events::*;
use state::*;
use verify::{bridge_message_bytes, message_hash, verify_ed25519_preinstruction};

declare_id!("9RoCmfzrPkbpSCr9a74cJJPGbXtzcQos6bbcePu7aSUt");

#[program]
pub mod cross_chain {
    use super::*;

    /// Initialize the central Solana treasury PDA.
    pub fn initialize_treasury(ctx: Context<InitializeTreasury>) -> Result<()> {
        let treasury = &mut ctx.accounts.treasury;
        treasury.authority = ctx.accounts.authority.key();
        treasury.total_deposited = 0;
        treasury.total_harvested = 0;
        treasury.deposit_count = 0;
        treasury.bump = ctx.bumps.treasury;

        emit!(TreasuryInitialized {
            authority: treasury.authority,
            treasury: treasury.key(),
        });

        Ok(())
    }

    /// Initialize Helix bridge state (Solenoid 2).
    pub fn initialize_bridge(
        ctx: Context<InitializeBridge>,
        bridge_authority: Pubkey,
        max_slippage_bps: u16,
        min_harvest_amount: u64,
        bridge_fee_lamports: u64,
    ) -> Result<()> {
        require!(max_slippage_bps <= 500, CrossChainError::SlippageExceeded);

        let bridge = &mut ctx.accounts.bridge_state;
        bridge.authority = ctx.accounts.authority.key();
        bridge.bridge_authority = bridge_authority;
        bridge.treasury = ctx.accounts.treasury.key();
        bridge.coordinator = ctx.accounts.coordinator_state.key();
        bridge.swarm_ops_program = ctx.accounts.swarm_ops_program.key();
        bridge.paused = false;
        bridge.processing = false;
        bridge.harvest_nonce = 0;
        bridge.min_harvest_amount = min_harvest_amount;
        bridge.max_slippage_bps = max_slippage_bps;
        bridge.bridge_fee_lamports = bridge_fee_lamports;
        bridge.bump = ctx.bumps.bridge_state;

        emit!(BridgeInitialized {
            authority: bridge.authority,
            bridge_authority,
            treasury: bridge.treasury,
            max_slippage_bps,
        });

        Ok(())
    }

    /// Update bridge configuration (authority only).
    pub fn update_bridge_config(
        ctx: Context<AdminBridge>,
        bridge_authority: Option<Pubkey>,
        min_harvest_amount: Option<u64>,
        max_slippage_bps: Option<u16>,
        bridge_fee_lamports: Option<u64>,
    ) -> Result<()> {
        let bridge = &mut ctx.accounts.bridge_state;

        if let Some(auth) = bridge_authority {
            bridge.bridge_authority = auth;
        }
        if let Some(min) = min_harvest_amount {
            bridge.min_harvest_amount = min;
        }
        if let Some(bps) = max_slippage_bps {
            require!(bps <= 500, CrossChainError::SlippageExceeded);
            bridge.max_slippage_bps = bps;
        }
        if let Some(fee) = bridge_fee_lamports {
            bridge.bridge_fee_lamports = fee;
        }

        emit!(BridgeConfigUpdated {
            bridge_authority: bridge.bridge_authority,
            min_harvest_amount: bridge.min_harvest_amount,
            max_slippage_bps: bridge.max_slippage_bps,
            bridge_fee_lamports: bridge.bridge_fee_lamports,
        });

        Ok(())
    }

    /// Pause or unpause bridge operations (authority only).
    pub fn set_bridge_pause(ctx: Context<AdminBridge>, paused: bool) -> Result<()> {
        let bridge = &mut ctx.accounts.bridge_state;
        bridge.paused = paused;

        emit!(BridgePauseUpdated {
            paused,
            authority: ctx.accounts.authority.key(),
        });

        emit!(EventLog {
            kind: EVENT_KIND_PAUSE,
            origin_chain_id: 0,
            agent: ctx.accounts.authority.key(),
            amount: 0,
            status: if paused { 1 } else { 0 },
            message: [0u8; 32],
        });

        Ok(())
    }

    /// Agent-initiated cross-chain yield harvest (Helix → remote chain).
    pub fn trigger_remote_harvest(
        ctx: Context<TriggerRemoteHarvest>,
        origin_chain_id: u32,
        target_chain_id: u32,
        amount: u64,
        max_slippage_bps: u16,
        nonce: u64,
    ) -> Result<()> {
        ctx.accounts
            .coordinator_state
            .assert_bridge_operational()?;
        ctx.accounts.bridge_state.assert_operational()?;

        let bridge = &mut ctx.accounts.bridge_state;
        let expected_nonce = bridge
            .harvest_nonce
            .checked_add(1)
            .ok_or(CrossChainError::MathOverflow)?;
        require!(nonce == expected_nonce, CrossChainError::HarvestMismatch);

        require!(
            amount >= bridge.min_harvest_amount,
            CrossChainError::BelowMinimum
        );
        require!(
            max_slippage_bps <= bridge.max_slippage_bps,
            CrossChainError::SlippageExceeded
        );
        require!(origin_chain_id != 0, CrossChainError::InvalidOriginChain);

        // CPI: swarm_ops daily limit + permission check
        let cpi_accounts = swarm_ops::cpi::accounts::AuthorizeHarvest {
            cross_chain_program: ctx.accounts.cross_chain_program.to_account_info(),
            swarm_config: ctx.accounts.swarm_config.to_account_info(),
            agent_registry: ctx.accounts.agent_registry.to_account_info(),
        };
        let cpi_ctx = CpiContext::new(
            ctx.accounts.swarm_ops_program.to_account_info(),
            cpi_accounts,
        );
        swarm_ops::cpi::authorize_harvest(cpi_ctx, amount)?;

        bridge.processing = true;
        bridge.harvest_nonce = nonce;

        let harvest = &mut ctx.accounts.harvest_request;
        harvest.agent = ctx.accounts.agent.key();
        harvest.bridge_state = bridge.key();
        harvest.origin_chain_id = origin_chain_id;
        harvest.target_chain_id = target_chain_id;
        harvest.amount = amount;
        harvest.nonce = nonce;
        harvest.status = HarvestStatus::Bridging;
        harvest.created_at = Clock::get()?.unix_timestamp;
        harvest.completed_at = 0;
        harvest.bump = ctx.bumps.harvest_request;

        let msg = bridge_message_bytes(
            &harvest.key(),
            origin_chain_id,
            amount,
            nonce,
        );
        harvest.message_hash = message_hash(&msg);

        // Bridge fee to treasury
        if bridge.bridge_fee_lamports > 0 {
            system_program::transfer(
                CpiContext::new(
                    ctx.accounts.system_program.to_account_info(),
                    Transfer {
                        from: ctx.accounts.agent.to_account_info(),
                        to: ctx.accounts.treasury.to_account_info(),
                    },
                ),
                bridge.bridge_fee_lamports,
            )?;
        }

        bridge.processing = false;

        emit!(HarvestTriggered {
            agent: harvest.agent,
            harvest_request: harvest.key(),
            origin_chain_id,
            target_chain_id,
            amount,
            nonce,
            message_hash: harvest.message_hash,
        });

        emit!(EventLog {
            kind: EVENT_KIND_HARVEST,
            origin_chain_id,
            agent: harvest.agent,
            amount,
            status: HarvestStatus::Bridging as u8,
            message: harvest.message_hash,
        });

        Ok(())
    }

    /// Verified callback — bridged yield deposited into treasury PDA.
    pub fn receive_cross_chain_yield(
        ctx: Context<ReceiveCrossChainYield>,
        origin_chain_id: u32,
        amount: u64,
        nonce: u64,
    ) -> Result<()> {
        ctx.accounts
            .coordinator_state
            .assert_bridge_operational()?;
        ctx.accounts.bridge_state.assert_operational()?;

        let harvest = &mut ctx.accounts.harvest_request;
        require!(
            harvest.status == HarvestStatus::Bridging,
            CrossChainError::InvalidHarvestStatus
        );
        require_keys_eq!(harvest.agent, ctx.accounts.agent.key(), CrossChainError::HarvestMismatch);
        require!(harvest.nonce == nonce, CrossChainError::HarvestMismatch);
        require!(harvest.origin_chain_id == origin_chain_id, CrossChainError::HarvestMismatch);
        require!(harvest.amount == amount, CrossChainError::HarvestMismatch);

        let msg = bridge_message_bytes(&harvest.key(), origin_chain_id, amount, nonce);
        require!(
            message_hash(&msg) == harvest.message_hash,
            CrossChainError::HarvestMismatch
        );

        // Ed25519 signature verification via preceding instruction
        verify_ed25519_preinstruction(
            &ctx.accounts.instructions_sysvar.to_account_info(),
            &ctx.accounts.bridge_state.bridge_authority,
            &msg,
        )?;

        let bridge = &mut ctx.accounts.bridge_state;
        bridge.processing = true;

        system_program::transfer(
            CpiContext::new(
                ctx.accounts.system_program.to_account_info(),
                Transfer {
                    from: ctx.accounts.bridge_authority.to_account_info(),
                    to: ctx.accounts.treasury.to_account_info(),
                },
            ),
            amount,
        )?;

        let treasury = &mut ctx.accounts.treasury;
        treasury.record_deposit(amount)?;
        treasury.total_harvested = treasury
            .total_harvested
            .checked_add(amount)
            .ok_or(CrossChainError::MathOverflow)?;

        harvest.transition_to(HarvestStatus::Completed)?;
        harvest.completed_at = Clock::get()?.unix_timestamp;

        bridge.processing = false;

        emit!(YieldReceived {
            harvest_request: harvest.key(),
            agent: harvest.agent,
            origin_chain_id,
            amount,
            treasury_total: treasury.total_deposited,
            status: HarvestStatus::Completed as u8,
        });

        emit!(EventLog {
            kind: EVENT_KIND_RECEIVE,
            origin_chain_id,
            agent: harvest.agent,
            amount,
            status: HarvestStatus::Completed as u8,
            message: harvest.message_hash,
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct InitializeTreasury<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + Treasury::INIT_SPACE,
        seeds = [Treasury::SEED],
        bump,
    )]
    pub treasury: Account<'info, Treasury>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct InitializeBridge<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + BridgeState::INIT_SPACE,
        seeds = [BridgeState::SEED],
        bump,
    )]
    pub bridge_state: Account<'info, BridgeState>,

    #[account(
        seeds = [Treasury::SEED],
        bump = treasury.bump,
    )]
    pub treasury: Account<'info, Treasury>,

    #[account(
        seeds = [coordinator::state::CoordinatorState::SEED],
        bump = coordinator_state.bump,
    )]
    pub coordinator_state: Account<'info, coordinator::state::CoordinatorState>,

    /// CHECK: swarm_ops program id stored for CPI
    pub swarm_ops_program: UncheckedAccount<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct AdminBridge<'info> {
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [BridgeState::SEED],
        bump = bridge_state.bump,
        has_one = authority @ CrossChainError::Unauthorized,
    )]
    pub bridge_state: Account<'info, BridgeState>,
}

#[derive(Accounts)]
#[instruction(nonce: u64)]
pub struct TriggerRemoteHarvest<'info> {
    #[account(mut)]
    pub agent: Signer<'info>,

    #[account(
        mut,
        seeds = [BridgeState::SEED],
        bump = bridge_state.bump,
    )]
    pub bridge_state: Account<'info, BridgeState>,

    #[account(
        mut,
        seeds = [Treasury::SEED],
        bump = treasury.bump,
    )]
    pub treasury: Account<'info, Treasury>,

    #[account(
        init,
        payer = agent,
        space = 8 + HarvestRequest::INIT_SPACE,
        seeds = [
            HarvestRequest::SEED,
            agent.key().as_ref(),
            &nonce.to_le_bytes(),
        ],
        bump,
    )]
    pub harvest_request: Account<'info, HarvestRequest>,

    #[account(
        seeds = [coordinator::state::CoordinatorState::SEED],
        bump = coordinator_state.bump,
    )]
    pub coordinator_state: Account<'info, coordinator::state::CoordinatorState>,

    #[account(
        seeds = [swarm_ops::state::SwarmConfig::SEED],
        bump = swarm_config.bump,
    )]
    pub swarm_config: Account<'info, swarm_ops::state::SwarmConfig>,

    #[account(
        mut,
        seeds = [swarm_ops::state::AgentRegistry::SEED, agent.key().as_ref()],
        bump = agent_registry.bump,
    )]
    pub agent_registry: Account<'info, swarm_ops::state::AgentRegistry>,

    /// CHECK: CPI target
    #[account(constraint = swarm_ops_program.key() == bridge_state.swarm_ops_program)]
    pub swarm_ops_program: UncheckedAccount<'info>,

    /// CHECK: self program for CPI caller validation
    #[account(constraint = cross_chain_program.key() == crate::ID)]
    pub cross_chain_program: UncheckedAccount<'info>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct ReceiveCrossChainYield<'info> {
    #[account(mut)]
    pub bridge_authority: Signer<'info>,

    /// CHECK: Agent pubkey for harvest PDA derivation
    pub agent: UncheckedAccount<'info>,

    #[account(
        mut,
        seeds = [BridgeState::SEED],
        bump = bridge_state.bump,
        has_one = bridge_authority @ CrossChainError::Unauthorized,
    )]
    pub bridge_state: Account<'info, BridgeState>,

    #[account(
        mut,
        seeds = [
            HarvestRequest::SEED,
            agent.key().as_ref(),
            &harvest_request.nonce.to_le_bytes(),
        ],
        bump = harvest_request.bump,
    )]
    pub harvest_request: Account<'info, HarvestRequest>,

    #[account(
        mut,
        seeds = [Treasury::SEED],
        bump = treasury.bump,
    )]
    pub treasury: Account<'info, Treasury>,

    #[account(
        seeds = [coordinator::state::CoordinatorState::SEED],
        bump = coordinator_state.bump,
    )]
    pub coordinator_state: Account<'info, coordinator::state::CoordinatorState>,

    /// CHECK: Ed25519 verify introspection
    #[account(address = anchor_lang::solana_program::sysvar::instructions::ID)]
    pub instructions_sysvar: UncheckedAccount<'info>,

    pub system_program: Program<'info, System>,
}
