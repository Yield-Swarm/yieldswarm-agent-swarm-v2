use anchor_lang::prelude::*;

#[account]
pub struct BridgeState {
    pub authority: Pubkey,
    pub treasury: Pubkey,
    pub total_received: u64,
    pub last_harvest_ts: i64,
    pub bump: u8,
}

impl BridgeState {
    pub const LEN: usize = 32 + 32 + 8 + 8 + 1;
}

/// On-chain mirror of config/TREASURY_MANIFEST.json IoTeX hub entries.
#[account]
pub struct TreasuryRoutingConfig {
    pub authority: Pubkey,
    /// IoTeX treasury EVM address (20 bytes).
    pub iotex_treasury: [u8; 20],
    /// SHA-256 of BTC bech32 bridge address for IOPAY routing verification.
    pub btc_bridge_hash: [u8; 32],
    pub default_destination: u8,
    pub iotex_total_routed: u64,
    pub btc_bridge_total_routed: u64,
    pub bump: u8,
}

impl TreasuryRoutingConfig {
    pub const LEN: usize = 32 + 20 + 32 + 1 + 8 + 8 + 1;
}
