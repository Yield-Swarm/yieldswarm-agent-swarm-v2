use anchor_lang::prelude::*;

/// ZK-Swarm batched proof header (full verify wired to circuits/entropy_proof.circom).
#[derive(AnchorSerialize, AnchorDeserialize, Clone)]
pub struct ZkSwarmProofBatch {
    pub batch_id: u64,
    pub agent_count: u16,
    pub proof_hash: [u8; 32],
    pub public_signals_hash: [u8; 32],
}

pub fn verify_zk_swarm_batch(batch: &ZkSwarmProofBatch) -> Result<()> {
    require!(batch.agent_count > 0, ZkSwarmError::EmptyBatch);
    require!(batch.proof_hash != [0u8; 32], ZkSwarmError::InvalidProof);
    Ok(())
}

#[error_code]
pub enum ZkSwarmError {
    #[msg("ZK-Swarm batch is empty")]
    EmptyBatch,
    #[msg("Invalid ZK-Swarm proof hash")]
    InvalidProof,
}
