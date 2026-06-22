use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use errors::*;
use state::*;

declare_id!("6BbH4rvmxERTbcAbEat9SzT3N3P9fEFWvoAD3EsJ3BAz");

/// Permission bit: agent may call `trigger_remote_harvest`.
pub const PERM_HARVEST: u8 = 1 << 0;
/// Permission bit: agent may receive yield callbacks.
pub const PERM_RECEIVE: u8 = 1 << 1;

#[program]
pub mod swarm_ops {
    use super::*;

    /// Bind the authorized cross_chain program (one-time).
    pub fn initialize_swarm_config(
        ctx: Context<InitializeSwarmConfig>,
        cross_chain_program: Pubkey,
    ) -> Result<()> {
        let cfg = &mut ctx.accounts.swarm_config;
        cfg.authority = ctx.accounts.authority.key();
        cfg.cross_chain_program = cross_chain_program;
        cfg.bump = ctx.bumps.swarm_config;
        Ok(())
    }

    /// Register an agent in the 521-agent swarm with daily harvest limits.
    pub fn register_agent(
        ctx: Context<RegisterAgent>,
        daily_harvest_limit: u64,
        permissions: u8,
    ) -> Result<()> {
        let registry = &mut ctx.accounts.agent_registry;
        registry.authority = ctx.accounts.authority.key();
        registry.agent = ctx.accounts.agent.key();
        registry.daily_harvest_limit = daily_harvest_limit;
        registry.daily_harvest_used = 0;
        registry.permissions = permissions;
        registry.last_reset_day = Clock::get()?.unix_timestamp / 86_400;
        registry.total_harvests = 0;
        registry.bump = ctx.bumps.agent_registry;

        emit!(AgentRegistered {
            agent: registry.agent,
            daily_harvest_limit,
            permissions,
        });

        Ok(())
    }

    /// Update limits or permissions for a registered agent.
    pub fn update_agent_limits(
        ctx: Context<UpdateAgent>,
        daily_harvest_limit: Option<u64>,
        permissions: Option<u8>,
    ) -> Result<()> {
        require_keys_eq!(
            ctx.accounts.authority.key(),
            ctx.accounts.agent_registry.authority,
            SwarmOpsError::Unauthorized
        );

        let registry = &mut ctx.accounts.agent_registry;
        if let Some(limit) = daily_harvest_limit {
            registry.daily_harvest_limit = limit;
        }
        if let Some(perms) = permissions {
            registry.permissions = perms;
        }

        emit!(AgentLimitsUpdated {
            agent: registry.agent,
            daily_harvest_limit: registry.daily_harvest_limit,
            permissions: registry.permissions,
        });

        Ok(())
    }

    /// Consume harvest quota — called via CPI from cross_chain.
    pub fn authorize_harvest(ctx: Context<AuthorizeHarvest>, amount: u64) -> Result<()> {
        require_keys_eq!(
            ctx.accounts.cross_chain_program.key(),
            ctx.accounts.swarm_config.cross_chain_program,
            SwarmOpsError::UnauthorizedCaller
        );

        let registry = &mut ctx.accounts.agent_registry;
        registry.reset_day_if_needed()?;

        require!(
            registry.permissions & PERM_HARVEST != 0,
            SwarmOpsError::HarvestNotPermitted
        );

        let new_used = registry
            .daily_harvest_used
            .checked_add(amount)
            .ok_or(SwarmOpsError::MathOverflow)?;

        require!(
            new_used <= registry.daily_harvest_limit,
            SwarmOpsError::DailyLimitExceeded
        );

        registry.daily_harvest_used = new_used;
        registry.total_harvests = registry
            .total_harvests
            .checked_add(1)
            .ok_or(SwarmOpsError::MathOverflow)?;

        emit!(HarvestAuthorized {
            agent: registry.agent,
            amount,
            daily_harvest_used: registry.daily_harvest_used,
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct InitializeSwarmConfig<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + SwarmConfig::INIT_SPACE,
        seeds = [SwarmConfig::SEED],
        bump,
    )]
    pub swarm_config: Account<'info, SwarmConfig>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct RegisterAgent<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    /// CHECK: Agent pubkey being registered (may be offline).
    pub agent: UncheckedAccount<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + AgentRegistry::INIT_SPACE,
        seeds = [AgentRegistry::SEED, agent.key().as_ref()],
        bump,
    )]
    pub agent_registry: Account<'info, AgentRegistry>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct UpdateAgent<'info> {
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [AgentRegistry::SEED, agent_registry.agent.as_ref()],
        bump = agent_registry.bump,
    )]
    pub agent_registry: Account<'info, AgentRegistry>,
}

#[derive(Accounts)]
pub struct AuthorizeHarvest<'info> {
    /// Cross-chain program invoking harvest authorization (CPI caller).
    /// CHECK: Validated against swarm_config.cross_chain_program
    pub cross_chain_program: UncheckedAccount<'info>,

    #[account(
        seeds = [SwarmConfig::SEED],
        bump = swarm_config.bump,
    )]
    pub swarm_config: Account<'info, SwarmConfig>,

    #[account(
        mut,
        seeds = [AgentRegistry::SEED, agent_registry.agent.as_ref()],
        bump = agent_registry.bump,
    )]
    pub agent_registry: Account<'info, AgentRegistry>,
}

#[event]
pub struct AgentRegistered {
    pub agent: Pubkey,
    pub daily_harvest_limit: u64,
    pub permissions: u8,
}

#[event]
pub struct AgentLimitsUpdated {
    pub agent: Pubkey,
    pub daily_harvest_limit: u64,
    pub permissions: u8,
}

#[event]
pub struct HarvestAuthorized {
    pub agent: Pubkey,
    pub amount: u64,
    pub daily_harvest_used: u64,
}
