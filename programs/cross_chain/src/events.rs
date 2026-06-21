use anchor_lang::prelude::*;

#[event]
pub struct BridgeInitialized {
    pub authority: Pubkey,
    pub bridge_authority: Pubkey,
    pub treasury: Pubkey,
    pub max_slippage_bps: u16,
}

#[event]
pub struct BridgeConfigUpdated {
    pub bridge_authority: Pubkey,
    pub min_harvest_amount: u64,
    pub max_slippage_bps: u16,
    pub bridge_fee_lamports: u64,
}

#[event]
pub struct BridgePauseUpdated {
    pub paused: bool,
    pub authority: Pubkey,
}

#[event]
pub struct TreasuryInitialized {
    pub authority: Pubkey,
    pub treasury: Pubkey,
}

#[event]
pub struct HarvestTriggered {
    pub agent: Pubkey,
    pub harvest_request: Pubkey,
    pub origin_chain_id: u32,
    pub target_chain_id: u32,
    pub amount: u64,
    pub nonce: u64,
    pub message_hash: [u8; 32],
}

#[event]
pub struct YieldReceived {
    pub harvest_request: Pubkey,
    pub agent: Pubkey,
    pub origin_chain_id: u32,
    pub amount: u64,
    pub treasury_total: u64,
    pub status: u8,
}

#[event]
pub struct EventLog {
    pub kind: u8,
    pub origin_chain_id: u32,
    pub agent: Pubkey,
    pub amount: u64,
    pub status: u8,
    pub message: [u8; 32],
}

pub const EVENT_KIND_HARVEST: u8 = 1;
pub const EVENT_KIND_RECEIVE: u8 = 2;
pub const EVENT_KIND_PAUSE: u8 = 3;
pub const EVENT_KIND_ROUTE: u8 = 4;

#[event]
pub struct MiningRootRegistered {
    pub root_key: [u8; 32],
    pub chain_id: u32,
    pub weight_bps: u16,
}

#[event]
pub struct YieldRoutedToRoot {
    pub root_key: [u8; 32],
    pub chain_id: u32,
    pub amount: u64,
    pub zk_batch_root: [u8; 32],
    pub total_routed: u64,
}
