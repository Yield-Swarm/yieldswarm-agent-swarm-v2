use anchor_lang::prelude::*;

#[event]
pub struct RemoteHarvestTriggered {
    pub authority: Pubkey,
    pub timestamp: i64,
}

#[event]
pub struct CrossChainYieldReceived {
    pub amount: u64,
    pub source_chain_id: u32,
    pub timestamp: i64,
}
