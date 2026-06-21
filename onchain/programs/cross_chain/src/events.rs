use anchor_lang::prelude::*;

#[event]
pub struct RemoteHarvestTriggered {
    pub authority: Pubkey,
    pub origin_chain_id: u32,
    pub target_treasury: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct CrossChainYieldReceived {
    pub amount: u64,
    pub source_chain_id: u32,
    pub treasury: Pubkey,
    pub agent: Pubkey,
    pub timestamp: i64,
}

/// Unified audit log for indexer / Geyser consumers.
#[event]
pub struct EventLog {
    pub kind: u8,
    pub program: Pubkey,
    pub actor: Pubkey,
    pub amount: u64,
    pub chain_id: u32,
    pub signature_hash: [u8; 32],
    pub timestamp: i64,
}

pub const EVENT_KIND_HARVEST_TRIGGER: u8 = 1;
pub const EVENT_KIND_YIELD_RECEIVED: u8 = 2;
