use anchor_lang::prelude::*;

#[event]
pub struct EventLog {
    pub kind: u8,
    pub origin_chain_id: u64,
    pub asset_amount: u64,
    pub agent: Pubkey,
    pub target_vault: Pubkey,
    pub bridge_message_hash: [u8; 32],
    pub timestamp: i64,
}

pub const EVENT_KIND_HARVEST_TRIGGER: u8 = 1;
pub const EVENT_KIND_YIELD_RECEIVED: u8 = 2;
