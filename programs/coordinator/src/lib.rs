use anchor_lang::prelude::*;

pub mod errors;
pub mod state;

use errors::*;
use state::*;

declare_id!("DXGVx4HsitGdFawg5KL68SAq9URhTaNL9tZAWWGGbo7p");

#[program]
pub mod coordinator {
    use super::*;

    /// Initialize the Nexus coordinator (Solenoid 1 backend orchestration root).
    pub fn initialize_coordinator(
        ctx: Context<InitializeCoordinator>,
        bridge_program: Pubkey,
    ) -> Result<()> {
        let state = &mut ctx.accounts.coordinator_state;
        state.authority = ctx.accounts.authority.key();
        state.bridge_program = bridge_program;
        state.global_paused = false;
        state.bridge_paused = false;
        state.bump = ctx.bumps.coordinator_state;
        state.version = 1;

        emit!(CoordinatorInitialized {
            authority: state.authority,
            bridge_program,
        });

        Ok(())
    }

    /// Global emergency pause — halts all coordinator-gated operations.
    pub fn set_global_pause(ctx: Context<SetPause>, paused: bool) -> Result<()> {
        let state = &mut ctx.accounts.coordinator_state;
        require_keys_eq!(
            ctx.accounts.authority.key(),
            state.authority,
            CoordinatorError::Unauthorized
        );

        state.global_paused = paused;

        emit!(GlobalPauseUpdated {
            paused,
            authority: ctx.accounts.authority.key(),
        });

        Ok(())
    }

    /// Bridge-specific pause (Solenoid 2 Helix ingress/egress).
    pub fn set_bridge_pause(ctx: Context<SetPause>, paused: bool) -> Result<()> {
        let state = &mut ctx.accounts.coordinator_state;
        require_keys_eq!(
            ctx.accounts.authority.key(),
            state.authority,
            CoordinatorError::Unauthorized
        );

        state.bridge_paused = paused;

        emit!(BridgePauseUpdated {
            paused,
            authority: ctx.accounts.authority.key(),
        });

        Ok(())
    }

    /// Update bridge program id (migration).
    pub fn update_bridge_program(
        ctx: Context<SetPause>,
        bridge_program: Pubkey,
    ) -> Result<()> {
        let state = &mut ctx.accounts.coordinator_state;
        require_keys_eq!(
            ctx.accounts.authority.key(),
            state.authority,
            CoordinatorError::Unauthorized
        );

        state.bridge_program = bridge_program;

        emit!(BridgeProgramUpdated {
            bridge_program,
            authority: ctx.accounts.authority.key(),
        });

        Ok(())
    }
}

#[derive(Accounts)]
pub struct InitializeCoordinator<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,

    #[account(
        init,
        payer = authority,
        space = 8 + CoordinatorState::INIT_SPACE,
        seeds = [CoordinatorState::SEED],
        bump,
    )]
    pub coordinator_state: Account<'info, CoordinatorState>,

    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct SetPause<'info> {
    pub authority: Signer<'info>,

    #[account(
        mut,
        seeds = [CoordinatorState::SEED],
        bump = coordinator_state.bump,
    )]
    pub coordinator_state: Account<'info, CoordinatorState>,
}

#[event]
pub struct CoordinatorInitialized {
    pub authority: Pubkey,
    pub bridge_program: Pubkey,
}

#[event]
pub struct GlobalPauseUpdated {
    pub paused: bool,
    pub authority: Pubkey,
}

#[event]
pub struct BridgePauseUpdated {
    pub paused: bool,
    pub authority: Pubkey,
}

#[event]
pub struct BridgeProgramUpdated {
    pub bridge_program: Pubkey,
    pub authority: Pubkey,
}
