use anchor_lang::prelude::*;
use crate::events::ArenaZkBatchVerified;
use crate::state::ArenaState;
use crate::zk_swarm::{verify_zk_swarm_batch, ZkSwarmProofBatch};

#[derive(Accounts)]
pub struct SubmitArenaZkBatch<'info> {
    pub verifier: Signer<'info>,
    #[account(
        mut,
        seeds = [b"arena_state"],
        bump = arena_state.bump
    )]
    pub arena_state: Account<'info, ArenaState>,
}

pub fn handler(ctx: Context<SubmitArenaZkBatch>, batch: ZkSwarmProofBatch) -> Result<()> {
    verify_zk_swarm_batch(&batch)?;
    let arena = &mut ctx.accounts.arena_state;
    arena.zk_batches_verified = arena.zk_batches_verified.saturating_add(1);

    emit!(ArenaZkBatchVerified {
        batch_id: batch.batch_id,
        agent_count: batch.agent_count,
        proof_hash: batch.proof_hash,
        verifier: ctx.accounts.verifier.key(),
        timestamp: Clock::get()?.unix_timestamp,
    });
    Ok(())
}
