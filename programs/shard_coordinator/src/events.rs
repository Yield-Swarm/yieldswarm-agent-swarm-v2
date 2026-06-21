use anchor_lang::prelude::*;

#[event]
pub struct ShardEventLog {
    pub kind: u8,
    pub shard_id: u16,
    pub amount: u64,
    pub efficiency_bps: u16,
    pub agent: Pubkey,
    pub timestamp: i64,
}

pub const EVENT_KIND_SHARD_CREATED: u8 = 1;
pub const EVENT_KIND_DEPOSIT: u8 = 2;
pub const EVENT_KIND_REBALANCE_OUT: u8 = 3;
pub const EVENT_KIND_REBALANCE_IN: u8 = 4;
