use anchor_lang::prelude::*;

/// On-chain agent reputation PDA — stores public score + proof hash only.
/// Private battle logs never touch chain; only committed hashes are anchored.
#[account]
pub struct AgentReputation {
    pub agent: Pubkey,
    pub score: u64,
    pub proof_hash: [u8; 32],
    pub last_update: i64,
    pub bump: u8,
}

impl AgentReputation {
    pub const LEN: usize = 8 + 32 + 8 + 32 + 8 + 1;
}

#[derive(Accounts)]
pub struct SubmitReputationProof<'info> {
    #[account(
        mut,
        seeds = [b"agent_reputation", agent.key().as_ref()],
        bump = agent_reputation.bump,
    )]
    pub agent_reputation: Account<'info, AgentReputation>,
    pub agent: Signer<'info>,
}

#[event]
pub struct ReputationUpdated {
    pub agent: Pubkey,
    pub score: u64,
    pub proof_hash: [u8; 32],
    pub timestamp: i64,
}

pub fn submit_reputation_proof(
    ctx: Context<SubmitReputationProof>,
    score: u64,
    proof_hash: [u8; 32],
) -> Result<()> {
    let rep = &mut ctx.accounts.agent_reputation;
    rep.agent = ctx.accounts.agent.key();
    rep.score = score;
    rep.proof_hash = proof_hash;
    rep.last_update = Clock::get()?.unix_timestamp;

    emit!(ReputationUpdated {
        agent: rep.agent,
        score: rep.score,
        proof_hash: rep.proof_hash,
        timestamp: rep.last_update,
    });

    Ok(())
}
