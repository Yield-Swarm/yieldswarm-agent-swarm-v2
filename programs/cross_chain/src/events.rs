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

/// Emitted when bridged or swept funds are routed to Nexus Treasury or a Mining Root.
#[event]
pub struct TreasuryRouteEvent {
    pub route_destination: u8,
    pub mining_root_kind: u8,
    pub origin_chain_id: u64,
    pub asset_amount: u64,
    pub solana_recipient: Pubkey,
    pub external_address: [u8; 64],
    pub external_address_len: u8,
    pub bridge_message_hash: [u8; 32],
    pub timestamp: i64,
}

pub const EVENT_KIND_HARVEST_TRIGGER: u8 = 1;
pub const EVENT_KIND_YIELD_RECEIVED: u8 = 2;
pub const EVENT_KIND_TREASURY_ROUTE: u8 = 3;
pub const EVENT_KIND_SWEEP: u8 = 4;
pub const EVENT_KIND_PAUSE: u8 = 5;
