use anchor_lang::prelude::*;

use crate::errors::CrossChainError;
use crate::mining_roots::{bootstrap_roots, nexus_treasury_default, write_root_entry};
use crate::state::{MiningRoot, TreasuryRegistry, MINING_ROOT_COUNT};

#[derive(Accounts)]
pub struct InitializeTreasuryRegistry<'info> {
    #[account(mut)]
    pub authority: Signer<'info>,
    #[account(
        init,
        payer = authority,
        space = TreasuryRegistry::LEN,
        seeds = [b"treasury_registry"],
        bump
    )]
    pub treasury_registry: Account<'info, TreasuryRegistry>,
    pub system_program: Program<'info, System>,
}

pub fn handler(ctx: Context<InitializeTreasuryRegistry>, nexus_authority: Pubkey) -> Result<()> {
    let registry = &mut ctx.accounts.treasury_registry;
    registry.authority = ctx.accounts.authority.key();
    registry.nexus_authority = nexus_authority;
    registry.nexus_treasury = nexus_treasury_default();
    registry.paused_sweeps = false;
    registry.paused_inflows = false;
    registry.total_to_nexus = 0;
    registry.total_to_mining = 0;
    registry.mining_root_count = MINING_ROOT_COUNT;
    registry.bump = ctx.bumps.treasury_registry;
    Ok(())
}

#[derive(Accounts)]
#[instruction(root_kind: u8)]
pub struct InitializeMiningRoot<'info> {
    #[account(mut)]
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
        init,
        payer = authority,
        space = MiningRoot::LEN,
        seeds = [b"mining_root", &[root_kind][..]],
        bump
    )]
    pub mining_root: Account<'info, MiningRoot>,
    pub system_program: Program<'info, System>,
}

pub fn init_mining_root_handler(ctx: Context<InitializeMiningRoot>, root_kind: u8) -> Result<()> {
    let bootstrap = bootstrap_roots()
        .into_iter()
        .find(|r| r.kind == root_kind)
        .ok_or(CrossChainError::UnknownRootKind)?;

    write_root_entry(
        &mut ctx.accounts.mining_root,
        ctx.accounts.treasury_registry.key(),
        &bootstrap,
        ctx.bumps.mining_root,
    );
    Ok(())
}
