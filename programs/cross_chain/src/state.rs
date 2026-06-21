use anchor_lang::prelude::*;

use crate::errors::CrossChainError;

/// Helix bridge global configuration.
#[account]
#[derive(InitSpace)]
pub struct BridgeState {
    pub authority: Pubkey,
    pub bridge_authority: Pubkey,
    pub treasury: Pubkey,
    pub coordinator: Pubkey,
    pub swarm_ops_program: Pubkey,
    pub paused: bool,
    pub processing: bool,
    pub harvest_nonce: u64,
    pub min_harvest_amount: u64,
    pub max_slippage_bps: u16,
    pub bridge_fee_lamports: u64,
    pub bump: u8,
}

impl BridgeState {
    pub const SEED: &'static [u8] = b"bridge_state";

    pub fn assert_operational(&self) -> Result<()> {
        require!(!self.paused, CrossChainError::BridgePaused);
        require!(!self.processing, CrossChainError::Reentrancy);
        Ok(())
    }

    pub fn next_nonce(&mut self) -> Result<u64> {
        self.harvest_nonce = self
            .harvest_nonce
            .checked_add(1)
            .ok_or(CrossChainError::MathOverflow)?;
        Ok(self.harvest_nonce)
    }
}

/// Central Solana treasury PDA — receives bridged yield.
#[account]
#[derive(InitSpace)]
pub struct Treasury {
    pub authority: Pubkey,
    pub total_deposited: u64,
    pub total_harvested: u64,
    pub deposit_count: u64,
    pub bump: u8,
}

impl Treasury {
    pub const SEED: &'static [u8] = b"treasury";

    pub fn record_deposit(&mut self, amount: u64) -> Result<()> {
        self.total_deposited = self
            .total_deposited
            .checked_add(amount)
            .ok_or(CrossChainError::MathOverflow)?;
        self.deposit_count = self
            .deposit_count
            .checked_add(1)
            .ok_or(CrossChainError::MathOverflow)?;
        Ok(())
    }
}

#[derive(AnchorSerialize, AnchorDeserialize, Clone, Copy, PartialEq, Eq, InitSpace)]
pub enum HarvestStatus {
    Pending = 0,
    Bridging = 1,
    Completed = 2,
    Failed = 3,
    Cancelled = 4,
}

/// Per-harvest request tracking cross-chain settlement.
#[account]
#[derive(InitSpace)]
pub struct HarvestRequest {
    pub agent: Pubkey,
    pub bridge_state: Pubkey,
    pub origin_chain_id: u32,
    pub target_chain_id: u32,
    pub amount: u64,
    pub nonce: u64,
    pub status: HarvestStatus,
    pub message_hash: [u8; 32],
    pub created_at: i64,
    pub completed_at: i64,
    pub bump: u8,
}

impl HarvestRequest {
    pub const SEED: &'static [u8] = b"harvest";

    pub fn seeds(agent: &Pubkey, nonce: u64) -> Vec<u8> {
        let mut v = Vec::with_capacity(8 + 32);
        v.extend_from_slice(Self::SEED);
        v.extend_from_slice(agent.as_ref());
        v.extend_from_slice(&nonce.to_le_bytes());
        v
    }

    pub fn transition_to(&mut self, next: HarvestStatus) -> Result<()> {
        let valid = match (self.status, next) {
            (HarvestStatus::Pending, HarvestStatus::Bridging) => true,
            (HarvestStatus::Bridging, HarvestStatus::Completed) => true,
            (HarvestStatus::Bridging, HarvestStatus::Failed) => true,
            (HarvestStatus::Pending, HarvestStatus::Cancelled) => true,
            _ => false,
        };
        require!(valid, CrossChainError::InvalidHarvestStatus);
        self.status = next;
        Ok(())
    }
}

/// Known chain identifiers for Helix routing.
pub mod chain_ids {
    pub const HELIX: u32 = 1;
    pub const SOLANA: u32 = 2;
    pub const ETHEREUM: u32 = 3;
    pub const IOTEX: u32 = 4689;
    pub const BASE: u32 = 8453;
}

/// Mining root destination registered for yield routing.
#[account]
#[derive(InitSpace)]
pub struct MiningRoot {
    pub authority: Pubkey,
    pub root_key: [u8; 32],
    pub chain_id: u32,
    pub destination_hash: [u8; 32],
    pub weight_bps: u16,
    pub total_routed: u64,
    pub bump: u8,
}

impl MiningRoot {
    pub const SEED: &'static [u8] = b"mining_root";
    pub const MAX_WEIGHT_BPS: u16 = 10_000;
}
