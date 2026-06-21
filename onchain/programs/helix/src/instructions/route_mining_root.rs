use anchor_lang::prelude::*;
use crate::events::{HelixYieldRouted, ZkSwarmBatchVerified};
use crate::mining_roots::MINING_ROOT_COUNT;
use crate::state::{HelixState, MiningRootConfig};
use crate::zk_swarm::{verify_zk_swarm_batch, ZkSwarmProofBatch};

#[derive(Accounts)]
pub struct RouteToMiningRoot<'info> {
    pub relayer: Signer<'info>,
    #[account(
        mut,
        seeds = [b"helix_state"],
        bump = helix_state.bump,
        constraint = helix_state.authority == relayer.key()
    )]
    pub helix_state: Account<'info, HelixState>,
    #[account(seeds = [b"mining_roots"], bump = mining_roots.bump)]
    pub mining_roots: Account<'info, MiningRootConfig>,
}

pub fn handler(
    ctx: Context<RouteToMiningRoot>,
    amount: u64,
    destination: u8,
    source_chain_id: u32,
) -> Result<()> {
    require!(amount > 0, HelixError::ZeroAmount);
    require!(destination < MINING_ROOT_COUNT, HelixError::InvalidDestination);

    let helix = &mut ctx.accounts.helix_state;
    helix.total_routed = helix.total_routed.saturating_add(amount);

    emit!(HelixYieldRouted {
        amount,
        destination,
        source_chain_id,
        nexus_treasury: helix.nexus_treasury,
        relayer: ctx.accounts.relayer.key(),
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}

#[derive(Accounts)]
pub struct SubmitZkSwarmBatch<'info> {
    pub verifier: Signer<'info>,
    #[account(
        mut,
        seeds = [b"helix_state"],
        bump = helix_state.bump
    )]
    pub helix_state: Account<'info, HelixState>,
}

pub fn submit_zk_handler(ctx: Context<SubmitZkSwarmBatch>, batch: ZkSwarmProofBatch) -> Result<()> {
    verify_zk_swarm_batch(&batch)?;
    let helix = &mut ctx.accounts.helix_state;
    helix.zk_batches_verified = helix.zk_batches_verified.saturating_add(1);
    emit!(ZkSwarmBatchVerified {
        batch_id: batch.batch_id,
        agent_count: batch.agent_count,
        proof_hash: batch.proof_hash,
        verifier: ctx.accounts.verifier.key(),
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}

#[error_code]
pub enum HelixError {
    #[msg("Amount must be greater than zero")]
    ZeroAmount,
    #[msg("Invalid mining root destination")]
    InvalidDestination,
}
