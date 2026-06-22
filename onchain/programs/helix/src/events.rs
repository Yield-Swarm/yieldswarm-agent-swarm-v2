use anchor_lang::prelude::*;

#[event]
pub struct HelixYieldRouted {
    pub amount: u64,
    pub destination: u8,
    pub source_chain_id: u32,
    pub nexus_treasury: Pubkey,
    pub relayer: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct ZkSwarmBatchVerified {
    pub batch_id: u64,
    pub agent_count: u16,
    pub proof_hash: [u8; 32],
    pub verifier: Pubkey,
    pub timestamp: i64,
}
