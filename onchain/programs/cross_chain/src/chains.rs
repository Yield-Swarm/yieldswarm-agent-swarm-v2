/// Chain identifiers for Helix / cross_chain routing.
pub const CHAIN_SOLANA: u32 = 0;
pub const CHAIN_HELIX: u32 = 0x0048_4c58; // "HLX"
pub const CHAIN_IOTEX: u32 = 0x0000_1250; // IoTeX chain id 4689 (lower 32 bits)
pub const CHAIN_IOPAY_BTC: u32 = 0x0049_4f50; // "IOP" — BTC bridge via IOPAY

pub const YIELD_DEST_NEXUS: u8 = 0;
pub const YIELD_DEST_IOTEX: u8 = 1;
pub const YIELD_DEST_BTC_IOPAY: u8 = 2;
