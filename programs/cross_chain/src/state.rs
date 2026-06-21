use anchor_lang::prelude::*;

/// Nexus Treasury on Solana — primary on-chain profit sink.
pub const DEFAULT_NEXUS_TREASURY: Pubkey = pubkey!("kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN");

pub const MAX_ADDRESS_LEN: usize = 64;
pub const MINING_ROOT_COUNT: u8 = 7;

// Mining root kind identifiers (stable indices for routing).
pub const ROOT_KIND_BASE_ETC: u8 = 0;
pub const ROOT_KIND_ZEC: u8 = 1;
pub const ROOT_KIND_PRL: u8 = 2;
pub const ROOT_KIND_TAO: u8 = 3;
pub const ROOT_KIND_BASE_HYPE: u8 = 4;
pub const ROOT_KIND_BASE_CBETH: u8 = 5;
pub const ROOT_KIND_BASE_BTC: u8 = 6;

// Sweep / inflow routing destinations.
pub const DEST_NEXUS_TREASURY: u8 = 0;
pub const DEST_MINING_ROOT: u8 = 1;

// Chain families for external roots.
pub const CHAIN_SOLANA: u8 = 0;
pub const CHAIN_EVM: u8 = 1;
pub const CHAIN_ZEC: u8 = 2;
pub const CHAIN_SUBSTRATE: u8 = 3;

// Shard sweep modes (used by coordinator CPI reads).
pub const SWEEP_INTERNAL_SOLANA: u8 = 0;
pub const SWEEP_EXTERNAL_MINING: u8 = 1;

#[account]
pub struct CrossChainConfig {
    pub authority: Pubkey,
    pub bridge_authority: Pubkey,
    pub treasury: Pubkey,
    pub helix_chain_id: u64,
    pub total_harvested: u64,
    pub total_received: u64,
    pub last_nonce: u64,
    pub bump: u8,
}

impl CrossChainConfig {
    pub const LEN: usize = 8 + 32 + 32 + 32 + 8 + 8 + 8 + 8 + 1;
}

#[account]
pub struct TreasuryVault {
    pub config: Pubkey,
    pub mint: Pubkey,
    pub balance: u64,
    pub bump: u8,
}

impl TreasuryVault {
    pub const LEN: usize = 8 + 32 + 32 + 8 + 1;
}

/// Central multi-chain treasury configuration PDA: seeds = [b"treasury_registry"]
#[account]
pub struct TreasuryRegistry {
    pub authority: Pubkey,
    /// Nexus Chain (Solenoid 1) authorized signer for root updates.
    pub nexus_authority: Pubkey,
    pub nexus_treasury: Pubkey,
    pub paused_sweeps: bool,
    pub paused_inflows: bool,
    pub total_to_nexus: u64,
    pub total_to_mining: u64,
    pub mining_root_count: u8,
    pub bump: u8,
}

impl TreasuryRegistry {
    pub const LEN: usize = 8 + 32 + 32 + 32 + 1 + 1 + 8 + 8 + 1 + 1;
}

/// Per-root DePIN / external reward sink: seeds = [b"mining_root", root_kind]
#[account]
pub struct MiningRoot {
    pub registry: Pubkey,
    pub root_kind: u8,
    pub chain_family: u8,
    /// UTF-8 or raw bytes (EVM = 20 bytes hex-decoded).
    pub address: [u8; 64],
    pub address_len: u8,
    /// Solana recipient when chain_family == CHAIN_SOLANA (e.g. PRL).
    pub solana_recipient: Pubkey,
    pub total_routed: u64,
    pub active: bool,
    pub bump: u8,
}

impl MiningRoot {
    pub const LEN: usize = 8 + 32 + 1 + 1 + 64 + 1 + 32 + 8 + 1 + 1;
}
