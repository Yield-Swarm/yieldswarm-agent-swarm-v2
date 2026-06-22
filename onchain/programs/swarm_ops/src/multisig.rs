use anchor_lang::prelude::*;

/// Multisig consensus helpers for swarm strategy proposals.
pub const DEFAULT_APPROVAL_THRESHOLD: u8 = 3;

pub fn record_approval(current: u8, threshold: u8) -> Result<bool> {
    let next = current.saturating_add(1);
    Ok(next >= threshold)
}

pub fn within_daily_limit(spent: u64, limit: u64, delta: u64) -> bool {
    spent.saturating_add(delta) <= limit
}
